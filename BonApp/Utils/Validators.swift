//
//  Validators.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//

import Foundation

/// Zbiór walidatorów
struct Validators {
    
    /// email
    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES[c] %@", pattern)
        return predicate.evaluate(with: email)
    }
    
    /// Hasło: przynajmniej 8 znaków, litery, cyfry
    static func isValidPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        let hasLetter = password.range(of: "[A-Za-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        return hasLetter && hasNumber
    }
    
    /// sprawdzenie pustych stringów
    static func isNonEmpty(_ string: String) -> Bool {
        return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// czy czas gotowania ma wartość dodatnią
    static func isValidCookTime(_ timeString: String) -> Bool {
        if let value = Int(timeString), value > 0 {
            return true
        }
        return false
    }
}
