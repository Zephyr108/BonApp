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
    @State private var preferences: String = ""
    @State private var avatarColor: Color = .blue
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    Text("Avatar")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Spacer()
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(avatarColor)
                            .padding()
                            .background(Color("textfieldBackground"))
                            .clipShape(Circle())
                        Spacer()
                    }

                    HStack {
                        Text("Kolor ikony")
                            .foregroundColor(Color("textPrimary"))
                        Spacer()
                        ColorPicker("", selection: $avatarColor)
                    }
                    .padding(16)
                    .background(Color("textfieldBackground"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("textfieldBorder"), lineWidth: 1)
                    )
                    .cornerRadius(8)

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

                    Text("Preferencje kulinarne")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Np. wegetariańskie, szybkie", text: $preferences)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

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

                    Text("Hasło")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    SecureField("Hasło", text: $password)
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

                    Button("Wyloguj") {
                        Task { await auth.signOut(); dismiss() }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color("logout"))
                    .foregroundColor(Color("buttonText"))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Ustaw profil")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color("background").ignoresSafeArea())
            .onAppear { syncFromAuthIfNeeded() }
            .onChange(of: auth.currentUser) { _, _ in syncFromAuthIfNeeded() }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func syncFromAuthIfNeeded() {
        guard let u = auth.currentUser else { return }
        if name.isEmpty { name = u.name ?? "" }
        if preferences.isEmpty { preferences = u.preferences ?? "" }
        if email.isEmpty { email = u.email }
        if let hex = u.avatarColorHex, let c = Color(hex: hex) { avatarColor = c }
    }

    private func saveProfile() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrefs = preferences.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPass = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = avatarColor.toHex() ?? "#000000"

        auth.updateProfile(
            name: trimmedName,
            preferences: trimmedPrefs,
            avatarColorHex: hex,
            email: trimmedEmail,
            password: trimmedPass
        )
        // AuthViewModel odświeży stan; zamknij po wywołaniu
        dismiss()
    }
}

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView()
            .environmentObject(AuthViewModel())
    }
}
