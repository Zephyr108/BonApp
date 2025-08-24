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

// MARK: - Supabase client access
// Provide your own singleton/DI. Ensure you have Supabase Swift SDK installed.
// Example:
// let supabase = SupabaseClient(supabaseURL: URL(string: "https://YOUR-PROJECT.supabase.co")!, supabaseKey: "YOUR_ANON_KEY")
final class SupabaseManager {
    static let shared = SupabaseManager()
    // Replace placeholders with your real URL & anon key.
    let client: SupabaseClient = SupabaseClient(
        supabaseURL: URL(string: "https://pksuyabrwexreslizpxp.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBrc3V5YWJyd2V4cmVzbGl6cHhwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUwMTI5NjksImV4cCI6MjA3MDU4ODk2OX0.RFeuz5qS7tyOXh1ph3ltBIQDdUt8WFsuLlWO0m7NEB4"
    )
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

    private let client: SupabaseClient
    private var cancellables = Set<AnyCancellable>()

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
        // Load session/user at startup
        Task { await refreshAuthState() }
    }

    // MARK: - Registration (sign up)
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
                let metadata: [String: AnyJSON] = [
                    "name": .string(name),
                    "preferences": preferences.isEmpty ? .null : .string(preferences),
                    "avatarColorHex": .string(avatarColorHex)
                ]

                try await client.auth.update(
                    user: UserAttributes(
                        email: email,
                        password: password,
                        data: metadata
                    )
                )

                // Re-read user and publish
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

    // MARK: - Logout
    func logout() {
        Task { @MainActor in
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
    private func refreshAuthState() async {
        do {
            // If a session exists, user is considered authenticated
            let session = try await client.auth.session
            self.isAuthenticated = (session != nil)

            if let user = try? await client.auth.user() {
                let meta = (user.userMetadata as? [String: Any]) ?? [:]
                let appUser = AppUser(
                    id: user.id.uuidString,
                    email: user.email ?? "",
                    name: meta["name"] as? String,
                    preferences: meta["preferences"] as? String,
                    avatarColorHex: meta["avatarColorHex"] as? String
                )
                self.currentUser = appUser
            } else {
                self.currentUser = nil
            }
        } catch {
            // If reading session/user fails, assume logged out
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }

    // MARK: - Backwards-compat shim (no-op)
    // Core Data used to clear local sessions. With Supabase this is handled by the Auth state.
    func clearOldSessions() {}
}
