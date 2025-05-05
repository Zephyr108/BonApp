import SwiftUI
import UIKit

// MARK: - View Helpers

extension View {
    /// Dismisses the keyboard from any text input.
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

// MARK: - String Helpers

extension String {
    /// Returns the string trimmed of whitespace and newlines.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Checks if the string contains any non-whitespace characters.
    var isNotEmpty: Bool {
        !trimmed.isEmpty
    }
    
    /// Splits a comma-separated string into an array of trimmed substrings.
    func splitCommaSeparated() -> [String] {
        split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

// MARK: - Collection Helpers

extension Collection {
    /// Safely returns the element at the given index if it exists.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - UIImage and Data Helpers

extension Data {
    /// Attempts to create a UIImage from this data.
    var asUIImage: UIImage? {
        UIImage(data: self)
    }
}

// MARK: - Color Hex Conversion

extension Color {
    init?(hex: String) {
        var hexString = hex
        if hexString.hasPrefix("#") {
            hexString = String(hexString.dropFirst())
        }

        guard hexString.count == 6,
              let intCode = Int(hexString, radix: 16) else {
            return nil
        }

        let red = Double((intCode >> 16) & 0xFF) / 255.0
        let green = Double((intCode >> 8) & 0xFF) / 255.0
        let blue = Double(intCode & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0

        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        let rgb = (Int(r * 255) << 16) |
                  (Int(g * 255) << 8) |
                  Int(b * 255)
        return String(format: "#%06X", rgb)
    }
}
