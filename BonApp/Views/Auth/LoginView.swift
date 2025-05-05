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
                        .autocapitalization(.none)
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

                    if let errorKey = auth.errorMessage {
                        Text(LocalizedStringKey(errorKey))
                            .foregroundColor(Color("logout"))
                    }

                    Button("Zaloguj") {
                        auth.login()
                    }
                    .disabled(!Validators.isValidEmail(auth.email) || auth.password.isEmpty)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color("login"))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            }
            .background(Color("background").ignoresSafeArea())
            .navigationTitle("Logowanie")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: auth.isAuthenticated) { oldValue, newValue in
                if newValue {
                    dismiss()
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel()) // <- to jest kluczowe
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
