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
        guard
            let pid = selectedProductId,
            let uid = auth.currentUser?.id,
            !quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard qty > 0 else { return }

        struct ExistingRow: Decodable {
            let id: UUID
            let quantity: Double
        }

        struct InsertPayload: Encodable {
            let user_id: String
            let product_id: Int
            let quantity: Double
        }

        struct UpdatePayload: Encodable {
            let quantity: Double
        }

        let client = SupabaseManager.shared.client

        Task {
            do {
                let existing: [ExistingRow] = try await client
                    .from("pantry")
                    .select("id,quantity")
                    .eq("user_id", value: uid)
                    .eq("product_id", value: pid)
                    .limit(1)
                    .execute()
                    .value

                if let row = existing.first {
                    let newQuantity = row.quantity + qty

                    _ = try await client
                        .from("pantry")
                        .update(UpdatePayload(quantity: newQuantity))
                        .eq("id", value: row.id)
                        .execute()
                } else {
                    let payload = InsertPayload(user_id: uid, product_id: pid, quantity: qty)

                    _ = try await client
                        .from("pantry")
                        .insert(payload)
                        .execute()
                }

                await MainActor.run {
                    dismiss()
                }
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
