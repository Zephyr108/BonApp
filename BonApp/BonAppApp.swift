//
//  BonAppApp.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//

import SwiftUI
import CoreData

@main
struct BonAppApp: App {
    let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            LaunchScreenView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}

