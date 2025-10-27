//
//  SettingsView.swift
//  BonApp
//
//  Created by Marcin on 05/05/2025.
//

import SwiftUI

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

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

struct SettingsView: View {
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

                Text("Zmiana motywu zapisywana jest lokalnie na tym urządzeniu.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Ustawienia")
        .background(Color("background").ignoresSafeArea())
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
