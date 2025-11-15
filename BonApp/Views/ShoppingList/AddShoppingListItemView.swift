import SwiftUI

struct AddShoppingListItemView: View {
    // MARK: - Dependencies
    
    @Environment(\.dismiss) private var dismiss
    
    /// ID listy zakupów, do której dodajemy produkty
    let shoppingListId: UUID
    
    /// Callback wywoływany po poprawnym dodaniu pozycji
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
                // Produkt
                VStack(alignment: .leading, spacing: 8) {
                    Text("Produkt")
                        .font(.headline)
                    
                    TextField("Szukaj produktu", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onChange(of: searchText) { newValue in
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
                        .background(Color(.secondarySystemBackground))
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
                            .background(Color(.systemBackground))
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
    
    /// Wyszukiwanie produktów po nazwie.
    @MainActor
    private func searchProducts(matching query: String) async {
        // Czyścimy wyniki, jeśli użytkownik skasował tekst
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            return
        }

        isSearching = true
        errorMessage = nil

        do {
            let client = SupabaseManager.shared.client

            // Pobieramy produkty z bazy (tak jak w spiżarni)
            let rows: [ProductSuggestion] = try await client
                .from("product")
                .select("id,name,unit")
                .execute()
                .value

            // Filtrowanie po stronie aplikacji, bez użycia `ilike`
            let lower = trimmed.lowercased()
            let filtered = rows.filter { $0.name.lowercased().contains(lower) }

            // Maksymalnie 5 propozycji
            suggestions = Array(filtered.prefix(5))
        } catch {
            // Nie blokujemy całego widoku, tylko pokazujemy komunikat
            errorMessage = "Nie udało się pobrać produktów: \(error.localizedDescription)"
        }

        isSearching = false
    }
    
    /// Zapisuje wybraną pozycję na liście zakupów (tabela `product_on_list`).
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
            
            // Powiadom widok nadrzędny i zamknij widok
            onAdded()
            dismiss()
        } catch {
            errorMessage = "Nie udało się dodać produktu: \(error.localizedDescription)"
        }
        
        isSaving = false
    }
}
