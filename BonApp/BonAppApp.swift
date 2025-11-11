//
//  BonAppApp.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//

import SwiftUI

@main
struct BonAppApp: App {
    @StateObject private var auth = AuthViewModel()
    @StateObject private var recipeVM = RecipeViewModel()
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("appAppearance") private var appAppearanceRaw = AppAppearance.system.rawValue
    private var appearance: AppAppearance { AppAppearance(rawValue: appAppearanceRaw) ?? .system }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(recipeVM)
                .preferredColorScheme(appearance.colorScheme)
                .task {
                    await auth.clearSessionOnLaunch()
                    await auth.refreshAuthState()
                }
        }
        .onChange(of: scenePhase) { old, newPhase in
            if newPhase == .active {
                Task { await auth.refreshAuthState() }
            }
        }
    }
}
