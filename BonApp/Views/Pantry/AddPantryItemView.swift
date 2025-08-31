import SwiftUI
import Supabase

struct AddPantryItemView: View {
    @State private var selectedProductId: Int? = nil
    @State private var quantity: String = ""
    @State private var products: [ProductRow] = []
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Produkt")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Picker("Wybierz produkt", selection: $selectedProductId) {
                        ForEach(products) { product in
                            Text(product.name).tag(Optional(product.id))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    Text("Ilość")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

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
                    let rows: [ProductRow] = try await SupabaseManager.shared.client.database
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
    }
    
    private func savePantryItem() {
        guard let pid = selectedProductId, let uid = auth.currentUser?.id else { return }
        let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1.0
        struct InsertPayload: Encodable { let user_id: String; let product_id: Int; let quantity: Double }
        let payload = InsertPayload(user_id: uid, product_id: pid, quantity: qty)

        let client = SupabaseManager.shared.client
        Task {
            do {
                _ = try await client.database
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
}

struct AddPantryItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddPantryItemView()
    }
}
