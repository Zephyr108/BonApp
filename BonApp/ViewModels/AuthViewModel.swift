//
//  AuthViewModel.swift
//  BonApp
//

import Foundation
import Combine
import Supabase

// MARK: - Helper model for the current user
struct AppUser: Equatable {
    let id: String
    var email: String
    var username: String?
    var name: String?
    var preferences: String?
    var preferences_array: [String]?
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
    let first_name: String?
    let last_name: String?
    let preferences: [String]?
}

private struct DBUserUpsert: Encodable {
    let id: String
    let email: String
    let username: String
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

    var activeUserId: String? { currentUser?.id }

    private let client: SupabaseClient
    private var cancellables = Set<AnyCancellable>()

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
        Task { await refreshAuthState() }
    }

    // MARK: - Registration
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

        func cleaned(_ s: String?) -> String? {
            let t = (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { return nil }
            if t.uppercased() == "EMPTY" { return nil }
            return t
        }
        let cleanUsername = cleaned(userTrim)
        let cleanFirst    = cleaned(firstTrim)
        let cleanLast     = cleaned(lastTrim)

        guard Validators.isValidEmail(emailTrim) else { errorMessage = "InvalidEmail"; return }
        guard Validators.isValidPassword(password) else { errorMessage = "WeakPassword"; return }
        guard Validators.isNonEmpty(userTrim) else { errorMessage = "Username cannot be empty"; return }
        guard Validators.isNonEmpty(firstTrim) else { errorMessage = "First name cannot be empty"; return }

        do {
            var metadata = [String: AnyJSON]()
            if let v = cleanUsername { metadata["username"] = try AnyJSON(v) }
            if let v = cleanFirst    { metadata["first_name"] = try AnyJSON(v) }
            if let v = cleanLast     { metadata["last_name"]  = try AnyJSON(v) }
            if !preferences.isEmpty  { metadata["preferences"] = try AnyJSON(preferences) }

            let result = try await client.auth.signUp(
                email: emailTrim,
                password: password,
                data: metadata
            )

            guard result.session != nil else {
                await refreshAuthState()
                if self.isAuthenticated == false { self.errorMessage = "Check your email to confirm the account." }
                return
            }

            var uidString: String?
            uidString = result.user.id.uuidString
            if uidString == nil || uidString?.isEmpty == true, let authUser = try? await client.auth.user() { uidString = authUser.id.uuidString }
            if uidString == nil || uidString?.isEmpty == true, let session = try? await client.auth.session { uidString = session.user.id.uuidString }

            guard let uid = uidString else {
                print("[Auth] Brak UID po rejestracji")
                await refreshAuthState()
                return
            }
            print("[Auth] upsert -> uid:", uid,
                  " username:", userTrim,
                  " first:", firstTrim,
                  " last:", lastTrim ?? "nil",
                  " prefs:", preferences)

            let update = DBUserUpdate(
                email: emailTrim,
                username: cleanUsername,
                first_name: cleanFirst,
                last_name: cleanLast,
                preferences: preferences.isEmpty ? nil : preferences
            )

            do {
                _ = try await client
                    .from("users")
                    .update(update)
                    .eq("id", value: uid)
                    .execute()
                print("[Auth] Uaktualniono użytkownika w public.users dla \(uid)")
            } catch {
                let nsErr = error as NSError
                if nsErr.domain != NSURLErrorDomain { print("[Auth] users update warning:", error.localizedDescription) }
            }

            await refreshAuthState()
            self.email = ""; self.password = ""; self.name = ""; self.preferences = ""
        } catch {
            self.errorMessage = "Registration failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Update profile (user metadata, email, password)
    func updateProfile(
        name: String,
        lastName: String,
        username: String,
        preferences: String,
        email: String,
        password: String?
    ) async {
        guard currentUser != nil else {
            self.errorMessage = "No authenticated user."
            return
        }
        guard Validators.isValidEmail(email) else {
            self.errorMessage = "InvalidEmail"
            return
        }
        guard Validators.isNonEmpty(name) else {
            self.errorMessage = "Name cannot be empty"
            return
        }

        let prefsArray = preferences
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        do {
            let update = DBUserUpdate(
                email: email,
                username: username.isEmpty ? nil : username,
                first_name: name,
                last_name: lastName.isEmpty ? nil : lastName,
                preferences: prefsArray.isEmpty ? nil : prefsArray
            )

            if let newPass = password, !newPass.trimmingCharacters(in: .whitespaces).isEmpty {
                try await client.auth.update(user: UserAttributes(password: newPass))
            }

            if let authUser = try? await client.auth.user() {
                _ = try await client
                    .from("users")
                    .update(update)
                    .eq("id", value: authUser.id.uuidString)
                    .execute()

                await refreshAuthState()
            }
        } catch {
            self.errorMessage = "Failed to save profile: \(error.localizedDescription)"
        }
    }


    // MARK: - Login
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

    // MARK: - Logout
    @MainActor
    func logout() async {
        await signOut()
    }

    @MainActor
    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
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
        if isRefreshingAuth { return }
        isRefreshingAuth = true
        defer { isRefreshingAuth = false }

        do {
            guard let authUser = try? await client.auth.user() else {
                self.isAuthenticated = false
                self.currentUser = nil
                return
            }

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
                        email: authUser.email ?? "",
                        username: row.username,
                        name: displayName.isEmpty ? row.first_name : displayName,
                        preferences: prefsArray == nil ? nil : prefsString,
                        preferences_array: prefsArray,
                        first_name: row.first_name,
                        last_name: row.last_name
                    )
                    do {
                        let usernameSanitized = row.username?.trimmingCharacters(in: .whitespaces) ?? ""
                        let firstSanitizedRaw = row.first_name.trimmingCharacters(in: .whitespaces)
                        let firstSanitized = (firstSanitizedRaw.isEmpty || firstSanitizedRaw.uppercased() == "EMPTY") ? "" : firstSanitizedRaw
                        let lastSanitized = (row.last_name ?? "").trimmingCharacters(in: .whitespaces)

                        var md = [String: AnyJSON]()
                        if !firstSanitized.isEmpty { md["first_name"] = try AnyJSON(firstSanitized) }
                        if !lastSanitized.isEmpty { md["last_name"] = try AnyJSON(lastSanitized) }
                        if !usernameSanitized.isEmpty { md["username"] = try AnyJSON(usernameSanitized) }
                        if let prefs = row.preferences, !prefs.isEmpty { md["preferences"] = try AnyJSON(prefs) }

                        if !md.isEmpty {
                            try await client.auth.update(user: UserAttributes(data: md))
                        }
                    } catch {
                    }
                } else {
                    nextUser = AppUser(
                        id: authUser.id.uuidString,
                        email: authUser.email ?? "",
                        username: nil,
                        name: nil,
                        preferences: nil,
                        preferences_array: nil,
                        first_name: nil,
                        last_name: nil
                    )
                }
            }

            self.isAuthenticated = true
            self.currentUser = nextUser
        } catch {
            print("[Auth] refreshAuthState error:", error.localizedDescription)
        }
    }

    @MainActor
    func resolveActiveUserId() async -> String? {
        if let id = currentUser?.id { return id }
        if let user = try? await client.auth.user() { return user.id.uuidString }
        return nil
    }

    // MARK: - Backwards-compat shim
    func clearOldSessions() {}

    // MARK: - Clear session on app launch
    @MainActor
    func clearSessionOnLaunch() async {
        do {
            try await client.auth.signOut()
        } catch {
            print("[Auth] clearSessionOnLaunch error:", error.localizedDescription)
        }
        self.isAuthenticated = false
        self.currentUser = nil
        self.email = ""
        self.password = ""
        self.name = ""
        self.preferences = ""
        self.errorMessage = nil
    }
}
