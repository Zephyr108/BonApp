import SwiftUI
import UIKit

// MARK: - Helpery Widoków

extension View { //ukrywanie klawiatury
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

// MARK: - Helpery Stringów

extension String {
    //usuwanie pustych znaków
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    //sprawdzenie czy ciąg nie jest pusty
    var isNotEmpty: Bool {
        !trimmed.isEmpty
    }
    
    //dzielenie ciągów po , na tabele
    func splitCommaSeparated() -> [String] {
        split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

// MARK: - Helpery Kolekcji

extension Collection {
    // zwracanie elementu o danym indeksie jak istnieje
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Helpery UUImage

extension Data {
    //UUImage
    var asUIImage: UIImage? {
        UIImage(data: self)
    }
}

// MARK: - Zamiana koloru HEX

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
