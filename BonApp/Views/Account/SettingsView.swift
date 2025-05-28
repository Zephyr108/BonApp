//
//  SettingsView.swift
//  BonApp
//
//  Created by Marcin on 05/05/2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var user: User
    var body: some View {
        Form {
            Section(header: Text("Ustawienia").foregroundColor(Color("textSecondary"))) {
                Text("Wersja aplikacji: 1.0")
                    .foregroundColor(Color("textPrimary"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("background").ignoresSafeArea())
        .navigationTitle("Ustawienia")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let ctx = PersistenceController.shared.container.viewContext
        let sampleUser = User(context: ctx)
        return SettingsView(user: sampleUser)
            .environment(\.managedObjectContext, ctx)
    }
}

//To do
