//
//  Validators.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//

import Foundation

/// A collection of common input validators used throughout the app.
struct Validators {
    
    /// Validates that the given email has a valid format.
    /// - Parameter email: The email string to validate.
    /// - Returns: `true` if the email is valid, `false` otherwise.
    static func isValidEmail(_ email: String) -> Bool {
        // Basic RFC 5322 regex
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES[c] %@", pattern)
        return predicate.evaluate(with: email)
    }
    
    /// Validates that the password meets minimum strength requirements:
    /// at least 8 characters, including a letter and a number.
    /// - Parameter password: The password string to validate.
    /// - Returns: `true` if the password is strong enough, `false` otherwise.
    static func isValidPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        let hasLetter = password.range(of: "[A-Za-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        return hasLetter && hasNumber
    }
    
    /// Checks that the given string is not empty or whitespace-only.
    /// - Parameter string: The string to check.
    /// - Returns: `true` if the string contains non-whitespace characters, `false` otherwise.
    static func isNonEmpty(_ string: String) -> Bool {
        return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Validates that a cook time string represents a positive integer.
    /// - Parameter timeString: The string to validate.
    /// - Returns: `true` if it can be converted to an integer > 0, `false` otherwise.
    static func isValidCookTime(_ timeString: String) -> Bool {
        if let value = Int(timeString), value > 0 {
            return true
        }
        return false
    }
}
