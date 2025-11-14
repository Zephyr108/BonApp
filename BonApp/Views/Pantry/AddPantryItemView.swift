import SwiftUI
import Supabase

struct AddPantryItemView: View {
    @State private var productSearchText: String = ""
    @State private var selectedProductId: Int? = nil
    @State private var quantity: String = ""
    @State private var products: [ProductRow] = []
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    private var selectedProductUnit: String {
        guard
            let pid = selectedProductId,
            let product = products.first(where: { $0.id == pid }),
            let unit = product.unit,
            !unit.isEmpty
        else {
            return ""
        }
        return unit
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Produkt")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Szukaj produktu", text: $productSearchText)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

                    // Sugestie produktów po wpisaniu nazwy
                    if !productSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        let suggestions = products
                            .filter { $0.name.localizedCaseInsensitiveContains(productSearchText) }
                            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                            .prefix(5)

                        ForEach(Array(suggestions), id: \.id) { product in
                            Button {
                                selectedProductId = product.id
                                productSearchText = product.name
                            } label: {
                                HStack {
                                    Text(product.name)
                                        .foregroundColor(Color("textPrimary"))
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }

                    Text("Ilość")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
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

                        if !selectedProductUnit.isEmpty {
                            Text(selectedProductUnit)
                                .foregroundColor(Color("textSecondary"))
                                .padding(.trailing, 4)
                        }
                    }
                }
                .padding()
            }
            .background(Color("background").ignoresSafeArea())
            .navigationTitle("Dodaj produkt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dodaj") {
                        savePantryItem()
                        dismiss()
                    }
                    .disabled(
                        selectedProductId == nil ||
                        quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .task {
                do {
                    let rows: [ProductRow] = try await SupabaseManager.shared.client
                        .from("product")
                        .select()
                        .order("name")
                        .execute()
                        .value
                    self.products = rows
                    print("Loaded \(rows.count) products for pantry")
                } catch {
                    print("Failed to load products: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func savePantryItem() {
        guard let pid = selectedProductId, let uid = auth.currentUser?.id else { return }
        let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1.0
        struct InsertPayload: Encodable { let user_id: String; let product_id: Int; let quantity: Double }
        let payload = InsertPayload(user_id: uid, product_id: pid, quantity: qty)

        let client = SupabaseManager.shared.client
        Task {
            do {
                _ = try await client
                    .from("pantry")
                    .insert(payload)
                    .execute()
            } catch {
                print("Failed to save pantry item: \(error.localizedDescription)")
            }
        }
    }
}


private struct ProductRow: Decodable, Identifiable {
    let id: Int
    let name: String
    let product_category_id: Int?
    let unit: String?
}

struct AddPantryItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddPantryItemView()
    }
}
