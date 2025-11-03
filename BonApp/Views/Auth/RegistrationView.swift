import SwiftUI

struct RegistrationView: View {
    struct CategoryRow: Identifiable, Decodable, Hashable {
        let id: Int
        let name: String
    }

    @State private var categories: [CategoryRow] = []
    @State private var selectedCategoryIds: Set<Int> = []
    @State private var isPickingPreferences = false

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

                    Button {
                        isPickingPreferences = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Preferencje kulinarne")
                                    .foregroundColor(Color("textSecondary"))
                                let names = categories.filter { selectedCategoryIds.contains($0.id) }.map { $0.name }
                                Text(names.isEmpty ? "Wybierz kategorie" : names.joined(separator: ", "))
                                    .foregroundColor(Color("textPrimary"))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
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
                    .sheet(isPresented: $isPickingPreferences) {
                        NavigationStack {
                            List {
                                ForEach(categories) { cat in
                                    MultipleSelectionRow(title: cat.name, isSelected: selectedCategoryIds.contains(cat.id)) {
                                        if selectedCategoryIds.contains(cat.id) {
                                            selectedCategoryIds.remove(cat.id)
                                        } else {
                                            selectedCategoryIds.insert(cat.id)
                                        }
                                    }
                                }
                            }
                            .navigationTitle("Preferencje")
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Gotowe") { isPickingPreferences = false }
                                }
                            }
                        }
                        .presentationDetents([.medium, .large])
                    }

                    if let errorKey = auth.errorMessage {
                        Text(LocalizedStringKey(errorKey))
                            .foregroundColor(Color("logout"))
                    }

                    Button("Zarejestruj") {
                        Task {
                            let selectedNames = categories
                                .filter { selectedCategoryIds.contains($0.id) }
                                .map { $0.name }
                            await auth.register(
                                email: auth.email,
                                password: auth.password,
                                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                                preferences: selectedNames
                            )
                        }
                    }
                    .disabled({
                        let validEmail = Validators.isValidEmail(auth.email)
                        let validPassword = Validators.isValidPassword(auth.password)
                        let validUser = !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        let validFirst = !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        let validLast = !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        return !(validEmail && validPassword && validUser && validFirst && validLast)
                    }())
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
            .task {
                await loadCategories()
            }
        }
    }

    private func loadCategories() async {
        do {
            let client = SupabaseManager.shared.client
            let rows: [CategoryRow] = try await client
                .from("category")
                .select("id,name")
                .order("name", ascending: true)
                .execute()
                .value
            categories = rows
        } catch {
            print("[Registration] loadCategories error:", error.localizedDescription)
        }
    }
}

private struct MultipleSelectionRow: View {
    let title: String
    var isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
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
