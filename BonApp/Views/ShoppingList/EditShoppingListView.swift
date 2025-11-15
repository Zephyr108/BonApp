import SwiftUI
import Supabase

struct EditShoppingListItemView: View {
    let shoppingListId: UUID
    let initialProductId: Int
    let initialQuantity: Double

    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductId: Int
    @State private var quantity: String
    @State private var products: [ProductRow] = []
    @State private var isSaving = false
    @State private var isLoading = false

    init(shoppingListId: UUID, productId: Int, quantity: Double = 1.0) {
        self.shoppingListId = shoppingListId
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
                                Text(product.name).tag(product.id)
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
                    .disabled(isSaving || quantity.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding()
            }
            .navigationTitle("Edytuj pozycję listy zakupów")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadProducts() }
        }
    }

    private func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [ProductRow] = try await SupabaseManager.shared.client
                .from("product")
                .select("id,name,product_category_id")
                .order("name", ascending: true)
                .execute()
                .value
            self.products = rows
        } catch {
            print("Błąd ładowania produktów: \(error.localizedDescription)")
        }
    }

    private func saveChanges() {
        let pid = selectedProductId
        let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1.0
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let client = SupabaseManager.shared.client

                struct ProductOnListInsert: Encodable { let shopping_list_id: UUID; let product_id: Int; let count: Double; let is_bought: Bool }
                struct ProductOnListUpdate: Encodable { let count: Double?; let is_bought: Bool? }

                if pid != initialProductId {
                    _ = try await client
                        .from("product_on_list")
                        .delete()
                        .eq("shopping_list_id", value: shoppingListId)
                        .eq("product_id", value: initialProductId)
                        .execute()

                    let insertPayload = ProductOnListInsert(shopping_list_id: shoppingListId, product_id: pid, count: qty, is_bought: false)
                    _ = try await client.from("product_on_list").insert(insertPayload).execute()
                } else {
                    let updatePayload = ProductOnListUpdate(count: qty, is_bought: nil)
                    _ = try await client
                        .from("product_on_list")
                        .update(updatePayload)
                        .eq("shopping_list_id", value: shoppingListId)
                        .eq("product_id", value: pid)
                        .execute()
                }

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

#Preview {
    NavigationStack {
        EditShoppingListItemView(shoppingListId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, productId: 1, quantity: 2.0)
    }
}
