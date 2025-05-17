import SwiftUI

struct AddShoppingListItemView: View {
    @State private var name: String = ""
    @State private var quantity: String = ""
    @State private var category: String = ""
    @Environment(\.dismiss) private var dismiss

    /// Callback when the user taps the Add button.
    let onSave: (_ name: String, _ quantity: String, _ category: String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color("background")
                    .ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Dodaj na listę zakupów")
                        .font(.headline)
                        .foregroundColor(Color("textPrimary"))
                        .padding(.top, 16)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nazwa produktu")
                            .foregroundColor(Color("textPrimary"))
                        TextField("Nazwa", text: $name)
                            .padding(16)
                            .background(Color("textfieldBackground"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color("textfieldBorder"), lineWidth: 1)
                            )
                            .cornerRadius(8)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ilość")
                            .foregroundColor(Color("textPrimary"))
                        TextField("Ilość", text: $quantity)
                            .keyboardType(.decimalPad)
                            .padding(16)
                            .background(Color("textfieldBackground"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color("textfieldBorder"), lineWidth: 1)
                            )
                            .cornerRadius(8)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kategoria")
                            .foregroundColor(Color("textPrimary"))
                        TextField("Kategoria", text: $category)
                            .padding(16)
                            .background(Color("textfieldBackground"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color("textfieldBorder"), lineWidth: 1)
                            )
                            .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        dismiss()
                    }
                    .foregroundColor(Color("textPrimary"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dodaj") {
                        onSave(
                            name.trimmingCharacters(in: .whitespacesAndNewlines),
                            quantity.trimmingCharacters(in: .whitespacesAndNewlines),
                            category.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        dismiss()
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                    .foregroundColor(Color("textPrimary"))
                }
            }
        }
    }
}

struct AddShoppingListItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddShoppingListItemView { name, quantity, category in
            // preview handler
        }
    }
}
