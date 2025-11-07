import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Login")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("E-mail", text: $auth.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)
                        .textContentType(.emailAddress)
                        .submitLabel(.next)

                    SecureField("Hasło", text: $auth.password)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)
                        .submitLabel(.go)
                        .onSubmit {
                            Task {
                                await auth.login()
                                print("[LoginView] after login: isAuthenticated=\(auth.isAuthenticated), error=\(auth.errorMessage ?? "nil")")
                                if auth.isAuthenticated {
                                    await auth.refreshAuthState()
                                    dismiss()
                                }
                            }
                        }

                    if let errorKey = auth.errorMessage {
                        Text(errorKey)
                            .foregroundColor(Color("logout"))
                    }

                    Button("Zaloguj") {
                        Task {
                            await auth.login()
                            print("[LoginView] after login: isAuthenticated=\(auth.isAuthenticated), error=\(auth.errorMessage ?? "nil")")
                            if auth.isAuthenticated {
                                // dociągnij profil/sesję zanim zamkniesz ekran, żeby ContentView miał już dane
                                await auth.refreshAuthState()
                                dismiss()
                            }
                        }
                    }
                    .disabled(auth.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || auth.password.isEmpty || auth.isLoading)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color("login"))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    if auth.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
                .padding()
            }
            .background(Color("background").ignoresSafeArea())
            .navigationTitle("Logowanie")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
