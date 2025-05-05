import SwiftUI
import CoreData

struct EditShoppingListItemView: View {
    @ObservedObject var item: ShoppingListItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var quantity: String

    init(item: ShoppingListItem) {
        self.item = item
        _name = State(initialValue: item.name ?? "")
        _quantity = State(initialValue: item.quantity ?? "")
    }

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
                Section {
                    Button("Zapisz zmiany") {
                        saveChanges()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                              quantity.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Edytuj pozycję listy zakupów")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func saveChanges() {
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.quantity = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Błąd zapisu pozycji listy zakupów: \(error.localizedDescription)")
        }
    }
}

struct EditShoppingListItemView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let sample = ShoppingListItem(context: context)
        sample.name = "Jajka"
        sample.quantity = "6 szt."
        return NavigationStack {
            EditShoppingListItemView(item: sample)
                .environment(\.managedObjectContext, context)
        }
    }
}
