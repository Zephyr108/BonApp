//
//  AuthViewModel.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//

import Foundation
import CoreData

final class AuthViewModel: ObservableObject {
    // MARK: - Dane
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var name: String = ""
    @Published var preferences: String = ""
    
    // MARK: - Statusy
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User? = nil
    @Published var errorMessage: String? = nil
    
    private let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
        clearOldSessions()
    }
    
    // MARK: - Rejestracja
    func register() {
        errorMessage = nil
        
        //Walidacja
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
        
        //Sprawdzenie maila czy nie jest używany
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email ==[c] %@", email)
        
        do {
            let existing = try viewContext.fetch(request)
            if !existing.isEmpty {
                errorMessage = "User with this email already exists"
                return
            }
        } catch {
            errorMessage = "Failed to validate email uniqueness: \(error.localizedDescription)"
            return
        }
        
        //Tworzenie uż
        let newUser = User(context: viewContext)
        newUser.email = email
        newUser.password = password
        newUser.name = name
        newUser.preferences = preferences
        newUser.avatarColorHex = "#000000"
        
        do {
            markUserAsCurrent(newUser)
            currentUser = newUser
            isAuthenticated = true
            try viewContext.save()
        } catch {
            viewContext.delete(newUser)
            errorMessage = "Registration failed: \(error.localizedDescription)"
        }
    }
    
    //Do oznaczenia danego użytkownika jako obecnego żeby tylko jeden na raz był zalogowany
    func markUserAsCurrent(_ user: User) {
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        
        do {
            let allUsers = try viewContext.fetch(fetchRequest)
            for u in allUsers {
                u.isCurrent = false
            }
            user.isCurrent = true
            try viewContext.save()
        } catch {
            print("Failed to mark user as current: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Profile
    //Update nazwy, preferencji, avatara, maila
    func updateProfile(name: String, preferences: String, avatarColorHex: String, email: String, password: String) {
        guard let user = currentUser else {
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

        user.name = name
        user.preferences = preferences.isEmpty ? nil : preferences
        user.avatarColorHex = avatarColorHex
        user.email = email
        user.password = password

        do {
            print("User object state before save: email=\(user.email ?? "nil"), password=\(user.password ?? "nil"), name=\(user.name ?? "nil"), preferences=\(user.preferences ?? "nil"), avatarColorHex=\(user.avatarColorHex ?? "nil")")
            try viewContext.save()
        } catch let error as NSError {
            if let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
                for detailedError in detailedErrors {
                    print("Validation error: \(detailedError), \(detailedError.userInfo)")
                }
            } else {
                print("Single validation error: \(error), \(error.userInfo)")
            }
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
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

        //Fetch pasującego uż
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email ==[c] %@ AND password == %@", email, password)
        request.fetchLimit = 1

        do {
            let results = try viewContext.fetch(request)
            if let user = results.first {
                let allUsers = try viewContext.fetch(User.fetchRequest())
                for u in allUsers {
                    u.isCurrent = false
                }

                user.isCurrent = true
                currentUser = user
                isAuthenticated = true
                try viewContext.save()
            } else {
                errorMessage = "Invalid email or password"
            }
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Logout
    //Wylogowanie obecnego uż
    func logout() {
        //Fetch wszystkich użytkowników i reset isCurrent
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        do {
            let users = try viewContext.fetch(fetchRequest)
            for user in users {
                user.isCurrent = false
            }
            try viewContext.save()
        } catch {
            print("Failed to reset isCurrent flags: \(error.localizedDescription)")
        }

        isAuthenticated = false
        currentUser = nil
        email = ""
        password = ""
        name = ""
        preferences = ""
    }
    //Czyszczenie starych sesji przez reset `isCurrent` dla wszystkich uż
    func clearOldSessions() {
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        do {
            let users = try viewContext.fetch(fetchRequest)
            for user in users {
                user.isCurrent = false
            }
            try viewContext.save()
        } catch {
            print("Failed to clear old sessions: \(error.localizedDescription)")
        }
    }
}
