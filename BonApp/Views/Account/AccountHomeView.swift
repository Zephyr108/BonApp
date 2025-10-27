//
//  AccountHomeView.swift
//  BonApp
//
//  Created by Marcin on 27/10/2025.
//

import SwiftUI

struct AccountHomeView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ProfileSetupView()
                } label: {
                    Label("Edytuj konto", systemImage: "person.crop.circle.badge.pencil")
                }

                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Ustawienia", systemImage: "gearshape.fill")
                }

                NavigationLink {
                    AboutView()
                } label: {
                    Label("O aplikacji", systemImage: "info.circle.fill")
                }
            }

            Section {
                Button(role: .destructive) {
                    Task {
                        await auth.logout()         // jeśli masz logout() async
                        // na wszelki wypadek “czyścimy sesję”
                        await auth.clearSessionOnLaunch()
                    }
                } label: {
                    Label("Wyloguj", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Konto")
    }
}
