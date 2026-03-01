import SwiftUI
import Supabase

struct EditPantryItemView: View {
    let itemId: UUID
    let productName: String
    let unit: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthViewModel

    @State private var quantity: String
    @State private var isSaving = false
    @State private var categoryName: String? = nil
    @State private var isLoadingCategory = false

    init(itemId: UUID, productName: String, unit: String?, quantity: String = "") {
        self.itemId = itemId
        self.productName = productName
        self.unit = unit
        _quantity = State(initialValue: quantity)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Produkt")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(productName)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .cornerRadius(8)

                    Text("Kategoria")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        if let name = categoryName, !name.isEmpty {
                            Text(name)
                                .foregroundColor(Color("textPrimary"))
                        } else if isLoadingCategory {
                            ProgressView().tint(Color("textSecondary"))
                        } else {
                            Text("—")
                                .foregroundColor(Color("textSecondary"))
                        }
                        Spacer()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("textfieldBackground"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("textfieldBorder"), lineWidth: 1)
                    )
                    .cornerRadius(8)

                    Text("Ilość")
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        TextField("Ilość", text: $quantity)
                            .keyboardType(.decimalPad)
                            .foregroundColor(Color("textPrimary"))

                        if let unit = unit, !unit.isEmpty {
                            Text(unit)
                                .foregroundColor(Color("textSecondary"))
                        }
                    }
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
                    .disabled(isSaving || quantity.trimmingCharacters(in: .whitespaces).isEmpty)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(isSaving ? Color("textfieldBorder") : Color("edit"))
                    .foregroundColor(Color("buttonText"))
                    .cornerRadius(8)
                }
                .padding()
            }
            .task { await loadCategoryName() }
            .background(Color("background").ignoresSafeArea())
            .navigationTitle("Edytuj pozycję spiżarni")
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
                struct UpdatePayload: Encodable { let quantity: Double }
                let payload = UpdatePayload(quantity: qty)
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

    private func loadCategoryName() async {
        isLoadingCategory = true
        defer { isLoadingCategory = false }
        do {
            struct PantryRow: Decodable { let product_id: Int }
            let pantry: PantryRow = try await SupabaseManager.shared.client
                .from("pantry")
                .select("product_id")
                .eq("id", value: itemId)
                .single()
                .execute()
                .value

            struct ProductRow: Decodable { let product_category_id: Int? }
            let product: ProductRow = try await SupabaseManager.shared.client
                .from("product")
                .select("product_category_id")
                .eq("id", value: pantry.product_id)
                .single()
                .execute()
                .value

            guard let catId = product.product_category_id else { return }

            struct CategoryRow: Decodable { let name: String }
            let category: CategoryRow = try await SupabaseManager.shared.client
                .from("product_category")
                .select("name")
                .eq("id", value: catId)
                .single()
                .execute()
                .value

            await MainActor.run { self.categoryName = category.name }
        } catch {
            // ignore errors; category stays nil
        }
    }
}

struct EditPantryItemView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EditPantryItemView(itemId: UUID(), productName: "Makaron", unit: "g", quantity: "2.0")
                .environmentObject(AuthViewModel())
        }
    }
}
