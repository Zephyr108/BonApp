//
//  AuthViewModel.swift
//  BonApp
//

import Foundation
import Combine
import Supabase

// MARK: - Helper model for the current user (metadata from Supabase)
struct AppUser: Equatable {
    let id: String
    var email: String
    /// Full display name (first + last) if available
    var name: String?
    /// Legacy string (comma-separated) for views that expect text
    var preferences: String?
    /// Native array from DB (text[])
    var preferences_array: [String]?
    /// Keep DB-style fields for legacy views expecting them
    var first_name: String?
    var last_name: String?
}

private struct DBUserRow: Decodable {
    let id: String
    let email: String
    let username: String?
    let first_name: String
    let last_name: String?
    let preferences: [String]?
}

private struct DBUserInsert: Encodable {
    let id: String
    let email: String
    let username: String?
    let first_name: String
    let last_name: String?
    let preferences: [String]?
}

private struct DBUserInsertNoId: Encodable {
    let email: String
    let username: String?
    let first_name: String
    let last_name: String?
    let preferences: [String]?
}

private struct DBUserUpdate: Encodable {
    let email: String
    let username: String?
    let first_name: String
    let last_name: String?
    let preferences: [String]?
}

final class AuthViewModel: ObservableObject {
    // MARK: - Inputs
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var name: String = ""
    @Published var preferences: String = ""

    // MARK: - State
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: AppUser? = nil
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false
    @Published private(set) var isRefreshingAuth: Bool = false

    /// Cached/cheap accessor: returns the user id if `currentUser` is already loaded; otherwise nil.
    var activeUserId: String? { currentUser?.id }

    private let client: SupabaseClient
    private var cancellables = Set<AnyCancellable>()

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
        // Load session/user at startup
        Task { await refreshAuthState() }
    }

    // MARK: - Registration (users table aware)
    @MainActor
    func register(email: String,
                  password: String,
                  username: String,
                  firstName: String,
                  lastName: String?,
                  preferences: [String]) async {
        errorMessage = nil

        let emailTrim = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let userTrim = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstTrim = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastTrim = lastName?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Validators.isValidEmail(emailTrim) else { errorMessage = "InvalidEmail"; return }
        guard Validators.isValidPassword(password) else { errorMessage = "WeakPassword"; return }
        guard Validators.isNonEmpty(userTrim) else { errorMessage = "Username cannot be empty"; return }
        guard Validators.isNonEmpty(firstTrim) else { errorMessage = "First name cannot be empty"; return }

        do {
            // 1) Sign up in Supabase Auth
            let result = try await client.auth.signUp(
                email: emailTrim,
                password: password
            )

            // 2) If no session yet (email confirmation flow), DO NOT insert to public.users now – RLS would reject.
            //    Poczekaj aż użytkownik się zaloguje po potwierdzeniu – wtedy refreshAuthState zadba o resztę.
            guard result.session != nil else {
                await refreshAuthState()
                // komunikat przyjazny – konto utworzone, sprawdź maila
                if self.isAuthenticated == false { self.errorMessage = "Check your email to confirm the account." }
                return
            }

            // 3) We have a session – insert profile row, letting DB assign id := auth.uid() by DEFAULT
            let insert = DBUserInsertNoId(
                email: emailTrim,
                username: userTrim,
                first_name: firstTrim,
                last_name: (lastTrim?.isEmpty == true ? nil : lastTrim),
                preferences: preferences.isEmpty ? nil : preferences
            )
            do {
                _ = try await client
                    .from("users")
                    .insert(insert)
                    .execute()
            } catch {
                // Jeśli polityka RLS nadal zablokuje (np. nietypowe ustawienia), nie psuj rejestracji
                let nsErr = error as NSError
                if nsErr.domain != NSURLErrorDomain { print("[Auth] users insert warning:", error.localizedDescription) }
            }

            // 4) Refresh local state
            await refreshAuthState()
            self.email = ""; self.password = ""; self.name = ""; self.preferences = ""
        } catch {
            self.errorMessage = "Registration failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Update profile (user metadata, email, password)
    func updateProfile(name: String, preferences: String, email: String, password: String) {
        guard currentUser != nil else {
            errorMessage = "No authenticated user."
            return
        }
        guard Validators.isValidEmail(email) else {
            errorMessage = "InvalidEmail"
            return
        }
        guard Validators.isValidPassword(password) else {
            errorMessage = "WeakPassword"
            return
        }
        guard Validators.isNonEmpty(name) else {
            errorMessage = "Name cannot be empty"
            return
        }

        Task { @MainActor in
            do {
                // Split display name into first/last
                let parts = name.split(separator: " ")
                let first = parts.first.map(String.init) ?? name
                let last = parts.dropFirst().joined(separator: " ")
                let lastOrNil = last.isEmpty ? nil : last

                // Update Auth user (email/password)
                try await client.auth.update(
                    user: UserAttributes(
                        email: email,
                        password: password
                    )
                )

                // Update public.users row
                if let authUser = try? await client.auth.user() {
                    let prefsArray = preferences.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    let update = DBUserUpdate(
                        email: email,
                        username: nil, // leave unchanged from this screen
                        first_name: first,
                        last_name: lastOrNil,
                        preferences: prefsArray.isEmpty ? nil : prefsArray
                    )
                    _ = try await client
                        .from("users")
                        .update(update)
                        .eq("id", value: authUser.id.uuidString)
                        .execute()
                }

                await refreshAuthState()
            } catch {
                self.errorMessage = "Failed to save profile: \(error.localizedDescription)"
            }
        }
    }


    // MARK: - Login (legacy wrapper)
    @available(*, deprecated, message: "Use async login() instead")
    func loginLegacy() {
        Task { await self.login() }
    }

    // MARK: - Login (async with retry)
    @MainActor
    func login() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let emailTrim = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = password

        var lastError: Error?
        for _ in 1...3 {
            do {
                try await signInInternal(email: emailTrim, password: pass)
                self.isAuthenticated = true
                // Refresh in background so we don't immediately overwrite the flag if session propagation lags
                Task { await self.refreshAuthState() }
                return
            } catch {
                lastError = error
                if let urlErr = error as? URLError, urlErr.code == .networkConnectionLost {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    continue
                }
                break
            }
        }

        if let urlErr = lastError as? URLError {
            self.errorMessage = "Błąd sieci (\(urlErr.code.rawValue)): \(urlErr.localizedDescription)"
            print("[Auth] URLError:", urlErr)
        } else {
            self.errorMessage = lastError?.localizedDescription ?? "Nieznany błąd logowania"
            print("[Auth] ERROR:", String(describing: lastError))
        }
    }

    private func signInInternal(email: String, password: String) async throws {
        try await SupabaseManager.shared.client.auth.signIn(email: email, password: password)
    }

    // MARK: - Logout (async)
    @MainActor
    func logout() async {
        await signOut()
    }

    /// Async sign-out API used by UI (ContentView). Non-throwing.
    @MainActor
    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            // Log but proceed to clear local state
            print("Sign out error: \(error.localizedDescription)")
        }
        self.isAuthenticated = false
        self.currentUser = nil
        self.email = ""
        self.password = ""
        self.name = ""
        self.preferences = ""
    }

    // MARK: - Session/User helpers
    @MainActor
    func refreshAuthState() async {
        // Prevent overlapping refreshes that cause flicker
        if isRefreshingAuth { return }
        isRefreshingAuth = true
        defer { isRefreshingAuth = false }

        do {
            // 1) Check session
            guard let authUser = try? await client.auth.user() else {
                // No session – mark logged out
                self.isAuthenticated = false
                self.currentUser = nil
                return
            }

            // 2) Try to load profile row; build AppUser
            var nextUser: AppUser
            do {
                let rows: [DBUserRow] = try await client
                    .from("users")
                    .select("id,email,username,first_name,last_name,preferences")
                    .eq("id", value: authUser.id.uuidString)
                    .limit(1)
                    .execute()
                    .value

                if let row = rows.first {
                    let displayName = [row.first_name, row.last_name ?? ""].joined(separator: " ")
                        .trimmingCharacters(in: .whitespaces)
                    let prefsArray = row.preferences
                    let prefsString = (prefsArray ?? []).joined(separator: ", ")
                    nextUser = AppUser(
                        id: row.id,
                        email: row.email,
                        name: displayName.isEmpty ? row.first_name : displayName,
                        preferences: prefsArray == nil ? nil : prefsString,
                        preferences_array: prefsArray,
                        first_name: row.first_name,
                        last_name: row.last_name
                    )
                } else {
                    nextUser = AppUser(
                        id: authUser.id.uuidString,
                        email: authUser.email ?? "",
                        name: nil,
                        preferences: nil,
                        preferences_array: nil,
                        first_name: nil,
                        last_name: nil
                    )
                }
            }

            // 3) Publish once (prevents temporary fallback to logged-out)
            self.isAuthenticated = true
            self.currentUser = nextUser
        } catch {
            // Network/temporary problems – do not flip to logged-out state
            print("[Auth] refreshAuthState error:", error.localizedDescription)
        }
    }

    /// Resolve the active user id. If the profile row hasn't loaded yet, falls back to the Supabase Auth user id.
    @MainActor
    func resolveActiveUserId() async -> String? {
        if let id = currentUser?.id { return id }
        if let user = try? await client.auth.user() { return user.id.uuidString }
        return nil
    }

    // MARK: - Backwards-compat shim (no-op)
    // Core Data used to clear local sessions. With Supabase this is handled by the Auth state.
    func clearOldSessions() {}

    // MARK: - Clear session on app launch
    @MainActor
    func clearSessionOnLaunch() async {
        do {
            try await client.auth.signOut()
        } catch {
            print("[Auth] clearSessionOnLaunch error:", error.localizedDescription)
        }
        // Wyczyszczenie stanu lokalnego
        self.isAuthenticated = false
        self.currentUser = nil
        self.email = ""
        self.password = ""
        self.name = ""
        self.preferences = ""
        self.errorMessage = nil
    }
}
