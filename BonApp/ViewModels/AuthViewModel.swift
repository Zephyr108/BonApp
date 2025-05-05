//
//  AuthViewModel.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//

import Foundation
import CoreData

/// ViewModel responsible for user authentication and registration.
final class AuthViewModel: ObservableObject {
    // MARK: - Published form fields
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var name: String = ""
    @Published var preferences: String = ""
    
    // MARK: - Published state
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User? = nil
    @Published var errorMessage: String? = nil
    
    // MARK: - Core Data context
    private let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
    }
    
    // MARK: - Registration
    /// Attempts to register a new user with the provided data.
    func register() {
        // Clear previous error
        errorMessage = nil
        
        // Validate inputs
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
        
        // Check if email already exists
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
        
        // Create new user
        let newUser = User(context: viewContext)
        newUser.email = email
        newUser.password = password
        newUser.name = name
        newUser.preferences = preferences
        
        do {
            try viewContext.save()
            currentUser = newUser
            isAuthenticated = true
        } catch {
            viewContext.delete(newUser)
            errorMessage = "Registration failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Login
    /// Attempts to log in with the provided email and password.
    func login() {
        errorMessage = nil
        
        // Simple validation
        guard Validators.isValidEmail(email) else {
            errorMessage = "InvalidEmail"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Password cannot be empty"
            return
        }
        
        // Fetch matching user
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email ==[c] %@ AND password == %@", email, password)
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            if let user = results.first {
                currentUser = user
                // Successful login
                isAuthenticated = true
                // Optionally store current user reference if needed
            } else {
                errorMessage = "Invalid email or password"
            }
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Logout
    /// Logs out the current user.
    func logout() {
        isAuthenticated = false
        currentUser = nil
        // Clear stored fields if desired
        email = ""
        password = ""
        name = ""
        preferences = ""
    }
}
