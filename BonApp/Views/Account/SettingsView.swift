//
//  SettingsView.swift
//  BonApp
//
//  Created by Marcin on 05/05/2025.
//

import SwiftUI

/// Lokalna preferencja motywu aplikacji.
/// Zapisywana w @AppStorage (UserDefaults), bez żadnej komunikacji z bazą.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Systemowy"
        case .light:  return "Jasny"
        case .dark:   return "Ciemny"
        }
    }

    /// Mapowanie na SwiftUI ColorScheme (nil oznacza: użyj ustawienia systemu).
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

struct SettingsView: View {
    // Przechowujemy wybór lokalnie – klucz możesz zmienić, jeśli masz swój namespacing.
    @AppStorage("appAppearance") private var appAppearanceRaw: String = AppAppearance.system.rawValue

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRaw) ?? .system
    }

    var body: some View {
        Form {
            Section(header: Text("Wygląd")) {
                Picker("Motyw", selection: $appAppearanceRaw) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                // Mała podpowiedź – zmiana jest lokalna. Globalne zastosowanie w całej aplikacji
                // najlepiej dodać w root view: `.preferredColorScheme(appearance.colorScheme)`
                // bazując na tym samym @AppStorage.
                Text("Zmiana motywu zapisywana jest lokalnie na tym urządzeniu.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Ustawienia")
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
