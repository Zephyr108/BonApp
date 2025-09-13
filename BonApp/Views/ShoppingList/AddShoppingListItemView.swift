import SwiftUI

struct AddShoppingListItemView: View {
    @State private var selectedProductId: Int? = nil
    @State private var quantity: String = ""
    @State private var products: [ProductRow] = []
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    let onSave: (_ productId: Int, _ quantity: Double) -> Void

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
                        Text("Produkt")
                            .foregroundColor(Color("textPrimary"))
                        Picker("Wybierz produkt", selection: $selectedProductId) {
                            ForEach(products) { product in
                                Text(product.name).tag(Optional(product.id))
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                    Spacer()
                }
                .padding(.horizontal, 16)
                .task {
                    do {
                        let rows: [ProductRow] = try await SupabaseManager.shared.client
                            .from("products")
                            .select("id,name,product_category_id")
                            .order("name")
                            .execute()
                            .value
                        self.products = rows
                    } catch {
                        print("Failed to load products: \(error.localizedDescription)")
                    }
                }
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
                        if let pid = selectedProductId {
                            let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1.0
                            onSave(pid, qty)
                        }
                        dismiss()
                    }
                    .disabled(
                        selectedProductId == nil ||
                        quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                    .foregroundColor(Color("textPrimary"))
                }
            }
        }
    }
}

private struct ProductRow: Decodable, Identifiable {
    let id: Int
    let name: String
    let product_category_id: Int?
}

struct AddShoppingListItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddShoppingListItemView { productId, quantity in
        }
    }
}
