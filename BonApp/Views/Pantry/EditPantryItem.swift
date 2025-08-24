import SwiftUI
import Supabase

struct EditPantryItemView: View {
    let itemId: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var quantity: String
    @State private var category: String
    @State private var isSaving = false

    init(itemId: UUID, name: String = "", quantity: String = "", category: String = "") {
        self.itemId = itemId
        _name = State(initialValue: name)
        _quantity = State(initialValue: quantity)
        _category = State(initialValue: category)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Nazwa produktu")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Nazwa", text: $name)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

                    Text("Ilość")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Ilość", text: $quantity)
                        .keyboardType(.decimalPad)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

                    Text("Kategoria")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Kategoria", text: $category)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

                    Spacer()
                    Button(isSaving ? "Zapisywanie…" : "Zapisz zmiany") {
                        saveChanges()
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty || quantity.trimmingCharacters(in: .whitespaces).isEmpty)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(isSaving ? Color("textfieldBorder") : Color("edit"))
                    .foregroundColor(Color("buttonText"))
                    .cornerRadius(8)
                }
                .padding()
            }
            .background(Color("background").ignoresSafeArea())
            .navigationTitle("Edytuj pozycję spiżarni")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func saveChanges() {
        let newName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newQty = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let newCat = category.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let client = SupabaseManager.shared.client
                _ = try await client.database
                    .from("pantry")
                    .update(["name": newName, "quantity": newQty, "category": newCat])
                    .eq("id", value: itemId)
                    .execute()
                dismiss()
            } catch {
                print("Błąd zapisu pozycji spiżarni: \(error.localizedDescription)")
            }
        }
    }
}

struct EditPantryItemView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EditPantryItemView(itemId: UUID(), name: "Mąka", quantity: "1 kg", category: "Pieczywo")
        }
    }
}
