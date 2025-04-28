//
//  BonAppApp.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//

import SwiftUI

@main
struct BonAppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
