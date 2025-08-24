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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
    }
}
