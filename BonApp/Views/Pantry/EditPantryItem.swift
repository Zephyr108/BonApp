import SwiftUI
import Supabase

struct EditPantryItemView: View {
    let itemId: UUID
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthViewModel

    @State private var selectedProductId: Int?
    @State private var quantity: String
    @State private var products: [ProductRow] = []
    @State private var isSaving = false

    init(itemId: UUID, productId: Int? = nil, quantity: String = "") {
        self.itemId = itemId
        _selectedProductId = State(initialValue: productId)
        _quantity = State(initialValue: quantity)
    }

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
                    .frame(maxWidth: .infinity, alignment: .leading)

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

                    Spacer()
                    Button(isSaving ? "Zapisywanie…" : "Zapisz zmiany") {
                        saveChanges()
                    }
                    .disabled(isSaving || selectedProductId == nil || quantity.trimmingCharacters(in: .whitespaces).isEmpty)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(isSaving ? Color("textfieldBorder") : Color("edit"))
                    .foregroundColor(Color("buttonText"))
                    .cornerRadius(8)
                }
                .padding()
            }
            .background(Color("background").ignoresSafeArea())
            .navigationTitle("Edytuj pozycję spiżarni")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadProducts() }
        }
    }

    private func loadProducts() async {
        do {
            let rows: [ProductRow] = try await SupabaseManager.shared.client
                .from("products")
                .select("id,name,product_category_id")
                .order("name")
                .execute()
                .value
            self.products = rows
        } catch {
            print("Błąd ładowania produktów: \(error.localizedDescription)")
        }
    }

    private func saveChanges() {
        guard let prodId = selectedProductId else { return }
        let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1.0
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let client = SupabaseManager.shared.client
                struct UpdatePayload: Encodable { let product_id: Int; let quantity: Double }
                let payload = UpdatePayload(product_id: prodId, quantity: qty)
                _ = try await client
                    .from("pantry")
                    .update(payload)
                    .eq("id", value: itemId)
                    .eq("user_id", value: auth.currentUser?.id ?? "")
                    .execute()
                dismiss()
            } catch {
                print("Błąd zapisu pozycji spiżarni: \(error.localizedDescription)")
            }
        }
    }
}

private struct ProductRow: Decodable, Identifiable {
    let id: Int
    let name: String
    let product_category_id: Int?
}

struct EditPantryItemView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EditPantryItemView(itemId: UUID(), productId: 1, quantity: "2.0")
                .environmentObject(AuthViewModel())
        }
    }
}
