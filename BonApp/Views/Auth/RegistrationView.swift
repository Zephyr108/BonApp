import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var preferences: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Rejestracja")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("E-mail", text: $auth.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

                    SecureField("Hasło", text: $auth.password)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)
                        .textContentType(.newPassword)

                    TextField("Nazwa użytkownika", text: $username)
                        .textInputAutocapitalization(.never)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

                    TextField("Imię", text: $firstName)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)
                        .textContentType(.givenName)

                    TextField("Nazwisko", text: $lastName)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)
                        .textContentType(.familyName)

                    TextField("Preferencje kulinarne", text: $preferences)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

                    if let errorKey = auth.errorMessage {
                        Text(LocalizedStringKey(errorKey))
                            .foregroundColor(Color("logout"))
                    }

                    Button("Zarejestruj") {
                        Task {
                            await auth.register(
                                email: auth.email,
                                password: auth.password,
                                username: username,
                                firstName: firstName,
                                lastName: lastName,
                                preferences: preferences
                            )
                        }
                    }
                    .disabled(
                        !Validators.isValidEmail(auth.email) ||
                        !Validators.isValidPassword(auth.password) ||
                        firstName.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color("register"))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            }
            .background(Color("background").ignoresSafeArea())
            .navigationTitle("Rejestracja")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: auth.isAuthenticated) { _, newValue in
                if newValue { dismiss() }
            }
        }
    }
}

struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        RegistrationView()
            .environmentObject(AuthViewModel())
    }
}
