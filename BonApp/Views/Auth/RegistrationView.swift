import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Rejestracja")
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

                    TextField("Imię", text: $auth.name)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

                    TextField("Preferencje kulinarne", text: $auth.preferences)
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
                        auth.register()
                    }
                    .disabled(
                        !Validators.isValidEmail(auth.email) ||
                        !Validators.isValidPassword(auth.password) ||
                        auth.name.trimmingCharacters(in: .whitespaces).isEmpty
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
            .onChange(of: auth.isAuthenticated) { oldValue, newValue in
                if newValue {
                    dismiss()
                }
            }
        }
    }
}

struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        RegistrationView()
            .environment(\.managedObjectContext, context)
            .environmentObject(AuthViewModel(context: context))
    }
}
