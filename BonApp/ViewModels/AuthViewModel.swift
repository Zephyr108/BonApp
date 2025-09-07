//
//  AuthViewModel.swift
//  BonApp
//
//  Migrated to Supabase Auth
//

import Foundation
import Combine
import Supabase

// MARK: - Helper model for the current user (metadata from Supabase)
struct AppUser: Equatable {
    let id: String
    var email: String
    var name: String?
    var preferences: String?
    var avatarColorHex: String?
}

private struct DBUserRow: Decodable {
    let id: String
    let email: String
    let username: String?
    let first_name: String
    let last_name: String?
    let preferences: String?
}

private struct DBUserInsert: Encodable {
    let id: String
    let email: String
    let username: String?
    let first_name: String
    let last_name: String?
    let preferences: String?
}

private struct DBUserUpdate: Encodable {
    let email: String
    let username: String?
    let first_name: String
    let last_name: String?
    let preferences: String?
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

    private let client: SupabaseClient
    private var cancellables = Set<AnyCancellable>()

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
        // Load session/user at startup
        Task { await refreshAuthState() }
    }

    // MARK: - Registration (legacy, uses metadata)
    func register() {
        errorMessage = nil

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
                // Attach initial metadata (name, prefs, avatar)
                let metadata: [String: AnyJSON] = [
                    "name": .string(name),
                    "preferences": preferences.isEmpty ? .null : .string(preferences),
                    "avatarColorHex": .string("#000000")
                ]

                _ = try await client.auth.signUp(
                    email: email,
                    password: password,
                    data: metadata
                )

                // After sign up, depending on your project settings, user may need to confirm email.
                // We refresh state; if a session exists, user is authenticated.
                await refreshAuthState()
                if !isAuthenticated {
                    errorMessage = "Check your email to confirm the account."
                }
            } catch {
                self.errorMessage = "Registration failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Registration (users table aware)
    @MainActor
    func register(email: String,
                  password: String,
                  username: String?,
                  firstName: String,
                  lastName: String?,
                  preferences: String?) async {
        errorMessage = nil

        guard Validators.isValidEmail(email) else { errorMessage = "InvalidEmail"; return }
        guard Validators.isValidPassword(password) else { errorMessage = "WeakPassword"; return }
        guard Validators.isNonEmpty(firstName) else { errorMessage = "Name cannot be empty"; return }

        do {
            // 1) Sign up in Supabase Auth
            _ = try await client.auth.signUp(
                email: email,
                password: password
            )

            // 2) Insert a row into public.users (FK id = auth.users.id)
            if let authUser = try? await client.auth.user() {
                let insert = DBUserInsert(
                    id: authUser.id.uuidString,
                    email: email,
                    username: username,
                    first_name: firstName,
                    last_name: lastName,
                    preferences: preferences
                )
                _ = try await client.database
                    .from("users")
                    .insert(insert)
                    .execute()
            }

            // 3) Refresh local state
            await refreshAuthState()
            self.email = ""; self.password = ""; self.name = ""; self.preferences = ""
        } catch {
            self.errorMessage = "Registration failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Update profile (user metadata, email, password)
    func updateProfile(name: String, preferences: String, avatarColorHex: String, email: String, password: String) {
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
                    let update = DBUserUpdate(
                        email: email,
                        username: nil, // leave unchanged from this screen
                        first_name: first,
                        last_name: lastOrNil,
                        preferences: preferences.isEmpty ? nil : preferences
                    )
                    _ = try await client.database
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

    // MARK: - Login
    func login() {
        errorMessage = nil

        guard Validators.isValidEmail(email) else {
            errorMessage = "InvalidEmail"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Password cannot be empty"
            return
        }

        Task { @MainActor in
            do {
                _ = try await client.auth.signIn(email: email, password: password)
                await refreshAuthState()
            } catch {
                self.errorMessage = "Invalid email or password"
            }
        }
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
        for attempt in 1...3 {
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
        do {
            try await client.auth.signOut()
        } catch {
            // Even if signOut throws (network), clear local state
            print("Sign out error: \(error.localizedDescription)")
        }
        self.isAuthenticated = false
        self.currentUser = nil
        self.email = ""
        self.password = ""
        self.name = ""
        self.preferences = ""
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
        do {
            if let authUser = try? await client.auth.user() {
                // We have an authenticated user
                self.isAuthenticated = true
                // fetch row from public.users
                let rows: [DBUserRow] = try await client.database
                    .from("users")
                    .select("id,email,username,first_name,last_name,preferences")
                    .eq("id", value: authUser.id.uuidString)
                    .limit(1)
                    .execute()
                    .value
                if let row = rows.first {
                    let displayName = [row.first_name, row.last_name ?? ""].joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    self.currentUser = AppUser(
                        id: row.id,
                        email: row.email,
                        name: displayName.isEmpty ? row.first_name : displayName,
                        preferences: row.preferences,
                        avatarColorHex: nil
                    )
                } else {
                    // No row in users yet — fall back to auth email
                    self.currentUser = AppUser(
                        id: authUser.id.uuidString,
                        email: authUser.email ?? "",
                        name: nil,
                        preferences: nil,
                        avatarColorHex: nil
                    )
                }
            } else {
                self.isAuthenticated = false
                self.currentUser = nil
            }
        } catch {
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }

    // MARK: - Backwards-compat shim (no-op)
    // Core Data used to clear local sessions. With Supabase this is handled by the Auth state.
    func clearOldSessions() {}
}
