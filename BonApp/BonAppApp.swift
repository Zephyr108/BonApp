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
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .task {
                    // Sync session and user row as early as possible
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
