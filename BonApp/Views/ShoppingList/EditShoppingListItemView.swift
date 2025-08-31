import SwiftUI
import Supabase

struct EditShoppingListItemView: View {
    let itemId: UUID
    let initialProductId: Int?
    let initialQuantity: Double

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthViewModel

    @State private var selectedProductId: Int?
    @State private var quantity: String
    @State private var products: [ProductRow] = []
    @State private var isSaving = false
    @State private var isLoading = false
    @State private var editingProduct: ProductRow?

    init(itemId: UUID, productId: Int? = nil, quantity: Double = 1.0) {
        self.itemId = itemId
        self.initialProductId = productId
        self.initialQuantity = quantity
        _selectedProductId = State(initialValue: productId)
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
                        Picker("Wybierz produkt", selection: $selectedProductId) {
                            ForEach(products) { product in
                                Text(product.name).tag(Optional(product.id))
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
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
                    .disabled(isSaving || selectedProductId == nil || quantity.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding()
            }
            .navigationTitle("Edytuj pozycję listy zakupów")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadProductsAndItem() }
        }
    }

    private func loadProductsAndItem() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Load products
            let rows: [ProductRow] = try await SupabaseManager.shared.client.database
                .from("products")
                .select("id,name,product_category_id")
                .order("name")
                .execute()
                .value
            self.products = rows

            // Load the shopping list item (with embedded product data)
            let client = SupabaseManager.shared.client
            let userId = auth.currentUser?.id ?? ""
            let query = client.database
                .from("shopping_list")
                .select("product_id,quantity,product:products(id,name,product_category_id)")
                .eq("id", value: itemId)
                .eq("user_id", value: userId)
                .limit(1)
            let items: [ShoppingListItemRow] = try await query.execute().value
            if let item = items.first {
                self.selectedProductId = item.product_id
                self.quantity = String(item.quantity)
                self.editingProduct = item.product
            }
        } catch {
            print("Błąd ładowania danych: \(error.localizedDescription)")
        }
    }

    private func saveChanges() {
        guard let pid = selectedProductId else { return }
        let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1.0
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let client = SupabaseManager.shared.client
                let userId = auth.currentUser?.id ?? ""
                struct UpdatePayload: Encodable { let product_id: Int; let quantity: Double }
                let payload = UpdatePayload(product_id: pid, quantity: qty)
                _ = try await client.database
                    .from("shopping_list")
                    .update(payload)
                    .eq("id", value: itemId)
                    .eq("user_id", value: userId)
                    .execute()
                dismiss()
            } catch {
                print("Błąd zapisu pozycji listy zakupów: \(error.localizedDescription)")
            }
        }
    }
}

private struct ProductRow: Decodable, Identifiable {
    let id: Int
    let name: String
    let product_category_id: Int?
}

private struct ShoppingListItemRow: Decodable {
    let product_id: Int
    let quantity: Double
    let product: ProductRow?
}

struct EditShoppingListItemView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EditShoppingListItemView(itemId: UUID(), productId: 1, quantity: 2.0)
                .environmentObject(AuthViewModel())
        }
    }
}
