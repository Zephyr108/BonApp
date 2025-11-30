import SwiftUI

struct AddShoppingListItemView: View {
    // MARK: - Dependencies
    
    @Environment(\.dismiss) private var dismiss
    
    let shoppingListId: UUID
    
    let onAdded: () -> Void
    
    // MARK: - Stan formularza
    
    @State private var searchText: String = ""
    @State private var suggestions: [ProductSuggestion] = []
    @State private var isSearching: Bool = false
    @State private var selectedProduct: ProductSuggestion?
    
    @State private var quantityText: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    
    private var parsedQuantity: Double? {
        let normalized = quantityText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
    
    private var isSaveDisabled: Bool {
        selectedProduct == nil || parsedQuantity == nil || isSaving
    }
    
    // MARK: - Init
    
    init(
        shoppingListId: UUID,
        onAdded: @escaping () -> Void = {}
    ) {
        self.shoppingListId = shoppingListId
        self.onAdded = onAdded
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Produkt")
                        .font(.headline)
                    
                    TextField("Szukaj produktu", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color("textfieldBackground"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color("textfieldBorder"), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onChange(of: searchText) { oldValue, newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                suggestions = []
                                return
                            }
                            if newValue == selectedProduct?.name {
                                return
                            }
                            Task { await searchProducts(matching: newValue) }
                        }
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.top, 4)
                    }
                    
                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(suggestions) { suggestion in
                                Button {
                                    withAnimation {
                                        selectedProduct = suggestion
                                        searchText = suggestion.name
                                        suggestions = []
                                    }
                                } label: {
                                    HStack {
                                        Text(suggestion.name)
                                        Spacer()
                                        if let unit = suggestion.unit, !unit.isEmpty {
                                            Text(unit)
                                                .foregroundColor(.secondary)
                                                .font(.subheadline)
                                        }
                                        if suggestion.id == selectedProduct?.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                
                                if suggestion.id != suggestions.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .background(Color("itemsListBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                
                // Ilość + jednostka
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ilość")
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        TextField("Ilość", text: $quantityText)
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color("textfieldBackground"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color("textfieldBorder"), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        
                        if let unit = selectedProduct?.unit, !unit.isEmpty {
                            Text(unit)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(minWidth: 40)
                        }
                    }
                }
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .background(Color("background").ignoresSafeArea())
            .navigationTitle("Dodaj produkt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveItem() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Dodaj")
                        }
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }
}

// MARK: - Supabase modele pomocnicze

private struct ProductSuggestion: Identifiable, Decodable {
    let id: Int
    let name: String
    let unit: String?
}

private struct NewShoppingListItemRow: Encodable {
    let quantity: Double
    let is_bought: Bool
    let shopping_list_id: UUID
    let product_id: Int
}

// MARK: - Logika sieciowa

extension AddShoppingListItemView {
    
    @MainActor
    private func searchProducts(matching query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            return
        }

        isSearching = true
        errorMessage = nil

        do {
            let client = SupabaseManager.shared.client

            let rows: [ProductSuggestion] = try await client
                .from("product")
                .select("id,name,unit")
                .execute()
                .value

            let lower = trimmed.lowercased()
            let filtered = rows.filter { $0.name.lowercased().contains(lower) }

            suggestions = Array(filtered.prefix(5))
        } catch {
            errorMessage = "Nie udało się pobrać produktów: \(error.localizedDescription)"
        }

        isSearching = false
    }
    
    @MainActor
    private func saveItem() async {
        guard let product = selectedProduct else {
            errorMessage = "Wybierz produkt z listy."
            return
        }
        guard let quantity = parsedQuantity, quantity > 0 else {
            errorMessage = "Podaj poprawną ilość."
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            let client = SupabaseManager.shared.client
            let payload = NewShoppingListItemRow(
                quantity: quantity,
                is_bought: false,
                shopping_list_id: shoppingListId,
                product_id: product.id
            )
            
            _ = try await client
                .from("product_on_list")
                .insert(payload)
                .execute()
            
            onAdded()
            dismiss()
        } catch {
            errorMessage = "Nie udało się dodać produktu: \(error.localizedDescription)"
        }
        
        isSaving = false
    }
}
