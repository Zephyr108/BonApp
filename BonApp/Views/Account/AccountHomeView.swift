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
                    Label("Edytuj konto", systemImage: "person.crop.circle")
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
                        await auth.logout()
                        await auth.clearSessionOnLaunch()
                    }
                } label: {
                    Label("Wyloguj", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(Color("logout"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Konto")
        .background(Color("background").ignoresSafeArea())
    }
}

#Preview {
    NavigationStack { AccountHomeView() }
}
