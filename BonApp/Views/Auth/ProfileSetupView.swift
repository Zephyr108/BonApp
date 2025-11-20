//
//  ProfileSetupView.swift
//  BonApp
//

import Foundation
import SwiftUI

struct ProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthViewModel

    @State private var name: String = ""
    @State private var lastName: String = ""
    @State private var username: String = ""
    @State private var preferences: String = ""
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    Text("Imię")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Wpisz imię", text: $name)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

                    Text("Nazwisko")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Wpisz nazwisko", text: $lastName)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

                    Text("Nazwa użytkownika")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Wpisz nazwę użytkownika", text: $username)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

                    Text("Preferencje kulinarne")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Menu {
                        Button("Danie główne") { preferences = "Danie główne" }
                        Button("Deser") { preferences = "Deser" }
                        Button("Sałatka") { preferences = "Sałatka" }
                        Button("Fast food domowy") { preferences = "Fast food domowy" }
                        Button("Przekąska") { preferences = "Przekąska" }
                    } label: {
                        HStack {
                            Text(preferences.isEmpty ? "Wybierz preferencje" : preferences)
                                .foregroundColor(Color("textPrimary"))
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(Color("textSecondary"))
                        }
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)
                    }

                    Text("Email")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Email", text: $email)
                        .foregroundColor(Color("textPrimary"))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

                    Text("Nowe hasło")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    SecureField("Wpisz nowe hasło", text: $password)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

                    Button("Zapisz profil") {
                        saveProfile()
                    }
                    .disabled(!canSave)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(canSave ? Color("edit") : Color("textfieldBorder"))
                    .foregroundColor(Color("buttonText"))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Ustaw profil")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color("background").ignoresSafeArea())
            .onAppear { syncFromAuthIfNeeded() }
            .onChange(of: auth.currentUser, initial: false) { _, _ in syncFromAuthIfNeeded() }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func syncFromAuthIfNeeded() {
        guard let u = auth.currentUser else { return }
        if name.isEmpty { name = u.first_name ?? "" }
        if lastName.isEmpty { lastName = u.last_name ?? "" }
        if username.isEmpty { username = u.username ?? "" }
        if preferences.isEmpty { preferences = u.preferences ?? "" }
        if email.isEmpty { email = u.email }
    }

    private func saveProfile() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrefs = preferences.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            await auth.updateProfile(
                name: trimmedName,
                lastName: trimmedLastName,
                username: trimmedUsername,
                preferences: trimmedPrefs,
                email: trimmedEmail,
                password: password.isEmpty ? nil : password
            )
            dismiss()
        }
    }
}

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView()
            .environmentObject(AuthViewModel())
    }
}
