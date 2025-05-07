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
            ZStack {
                Color("background").ignoresSafeArea()
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nazwa produktu")
                            .foregroundColor(Color("textPrimary"))
                        TextField("Nazwa", text: $name)
                            .padding()
                            .background(Color("textfieldBackground"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color("textfieldBorder"))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ilość")
                            .foregroundColor(Color("textPrimary"))
                        TextField("Ilość", text: $quantity)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(Color("textfieldBackground"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color("textfieldBorder"))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button("Zapisz zmiany") {
                        saveChanges()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("edit"))
                    .foregroundColor(Color("buttonText"))
                    .cornerRadius(8)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                              quantity.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding()
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
