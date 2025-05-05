import SwiftUI

struct AddShoppingListItemView: View {
    @State private var name: String = ""
    @State private var quantity: String = ""
    @Environment(\.dismiss) private var dismiss

    /// Callback when the user taps the Add button.
    let onSave: (_ name: String, _ quantity: String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Nazwa produktu")) {
                    TextField("Nazwa", text: $name)
                }
                Section(header: Text("Ilość")) {
                    TextField("Ilość", text: $quantity)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Dodaj na listę zakupów")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dodaj") {
                        onSave(
                            name.trimmingCharacters(in: .whitespacesAndNewlines),
                            quantity.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        dismiss()
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}

struct AddShoppingListItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddShoppingListItemView { name, quantity in
            // preview handler
        }
    }
}
