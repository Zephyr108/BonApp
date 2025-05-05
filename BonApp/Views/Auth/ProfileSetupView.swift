//
//  ProfileSetupView.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//

import SwiftUI
import CoreData

struct ProfileSetupView: View {
    @ObservedObject var user: User
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthViewModel

    @State private var name: String
    @State private var preferences: String
    @State private var avatarColor: Color

    init(user: User) {
        self.user = user
        _name = State(initialValue: user.name ?? "")
        _preferences = State(initialValue: user.preferences ?? "")
        if let hex = user.avatarColorHex, let color = Color(hex: hex) {
            _avatarColor = State(initialValue: color)
        } else {
            _avatarColor = State(initialValue: .blue)
        }
    }

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

                    Button("Zapisz profil") {
                        saveProfile()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color("edit"))
                    .foregroundColor(Color("textPrimary"))
                    .cornerRadius(8)

                    Button("Wyloguj") {
                        logout()
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color("logout"))
                    .foregroundColor(Color("textPrimary"))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Ustaw profil")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color("background").ignoresSafeArea())
        }
    }

    private func saveProfile() {
        user.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        user.preferences = preferences.trimmingCharacters(in: .whitespacesAndNewlines)
        user.avatarColorHex = avatarColor.toHex()
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Błąd zapisu profilu: \(error.localizedDescription)")
        }
    }

    private func logout() {
        auth.logout()
        dismiss()
    }
}

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let sampleUser = User(context: context)
        sampleUser.name = "Jan"
        sampleUser.preferences = "Wegetariańskie"
        return ProfileSetupView(user: sampleUser)
            .environment(\.managedObjectContext, context)
    }
}
