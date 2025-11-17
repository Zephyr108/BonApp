import SwiftUI
import Supabase

struct EditShoppingListItemView: View {
    let shoppingListId: UUID
    let initialProductId: Int
    let initialQuantity: Double
    let productName: String

    @Environment(\.dismiss) private var dismiss

    @State private var quantity: String
    @State private var isSaving = false

    init(shoppingListId: UUID, productId: Int, productName: String, quantity: Double) {
        self.shoppingListId = shoppingListId
        self.initialProductId = productId
        self.initialQuantity = quantity
        self.productName = productName
        _quantity = State(initialValue: String(quantity))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("background").ignoresSafeArea()
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Produkt")
                            .foregroundColor(Color("textPrimary"))
                        Text(productName)
                            .foregroundColor(Color("textSecondary"))
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

                    Button(isSaving ? "Zapisywanie…" : "Zapisz zmiany") {
                        saveChanges()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSaving ? Color("textfieldBorder") : Color("edit"))
                    .foregroundColor(Color("buttonText"))
                    .cornerRadius(8)
                    .disabled(isSaving || quantity.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding()
            }
            .navigationTitle("Edytuj pozycję listy zakupów")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func saveChanges() {
        let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1.0
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let client = SupabaseManager.shared.client

                struct ProductOnListUpdate: Encodable {
                    let quantity: Double
                }

                let updatePayload = ProductOnListUpdate(quantity: qty)
                _ = try await client
                    .from("product_on_list")
                    .update(updatePayload)
                    .eq("shopping_list_id", value: shoppingListId)
                    .eq("product_id", value: initialProductId)
                    .execute()

                dismiss()
            } catch {
                print("Błąd zapisu pozycji listy zakupów: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditShoppingListItemView(
            shoppingListId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            productId: 1,
            productName: "Makaron",
            quantity: 2.0
        )
    }
}
