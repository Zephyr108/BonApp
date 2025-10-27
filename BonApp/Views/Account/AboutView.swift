//
//  AboutView.swift
//  BonApp
//
//  Created by Marcin on 27/10/2025.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("BonApp")
                    .font(.largeTitle).bold()

                Text("Wersja 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                Text("BonApp pomaga zarządzać przepisami, spiżarnią i listami zakupów. "
                     + "Twoje dane są przechowywane bezpiecznie w Supabase.")
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 12)

                Text("Kontakt")
                    .font(.headline)
                Text("hello@bonapp.example")
            }
            .padding()
        }
        .navigationTitle("O aplikacji")
    }
}
