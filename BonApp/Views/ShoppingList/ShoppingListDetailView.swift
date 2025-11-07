import SwiftUI

struct ShoppingListDetailView: View {
    @StateObject private var viewModel: ShoppingListViewModel

    @State private var isPresentingSheet = false
    @State private var isEditing = false
    @State private var inputProductId: String = ""
    @State private var inputQuantity: String = "1"
    @State private var editingProductId: Int? = nil

    private let ownerId: String
    private let shoppingListId: UUID

    init(ownerId: String, shoppingListId: UUID) {
        _viewModel = StateObject(wrappedValue: ShoppingListViewModel(ownerId: ownerId, shoppingListId: shoppingListId))
        self.ownerId = ownerId
        self.shoppingListId = shoppingListId
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView("Brak pozycji", systemImage: "cart", description: Text("Dodaj produkty do tej listy zakupów."))
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.productName)
                                        .font(.headline)
                                    HStack(spacing: 8) {
                                        Text("Ilość:")
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.2f", item.count))
                                        if let cat = item.productCategoryId { Text("• kategoria #\(cat)").foregroundColor(.secondary) }
                                    }
                                    .font(.subheadline)
                                }
                                Spacer()
                                if item.isBought {
                                    Image(systemName: "checkmark.circle.fill")
                                } else {
                                    Image(systemName: "circle")
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { presentEdit(for: item) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { Task { await viewModel.deleteItem(productId: item.productId) } } label: {
                                    Label("Usuń", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if !item.isBought {
                                    Button { Task { await viewModel.markAsBought(productId: item.productId) } } label: {
                                        Label("Kupione", systemImage: "checkmark.circle")
                                    }.tint(.green)
                                }
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Lista zakupów")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await viewModel.transferBoughtItemsToPantry() }
                    } label: {
                        Label("Do spiżarni", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(!viewModel.items.contains(where: { $0.isBought }))
                    .help("Przenieś kupione pozycje do spiżarni")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { presentAdd() } label: { Image(systemName: "plus") }
                }
            }
            .task { await viewModel.fetchItems() }
            .alert("Błąd", isPresented: Binding(get: { viewModel.error != nil }, set: { _ in viewModel.error = nil })) {
                Button("OK", role: .cancel) { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
            .sheet(isPresented: $isPresentingSheet) { sheetView }
        }
    }

    // MARK: - Sheet for Add / Edit
    @ViewBuilder
    private var sheetView: some View {
        NavigationStack {
            Form {
                Section("Produkt") {
                    TextField("product_id (Int)", text: $inputProductId)
                        .keyboardType(.numberPad)
                }
                Section("Ilość") {
                    TextField("np. 1.0", text: $inputQuantity)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(isEditing ? "Edytuj pozycję" : "Dodaj pozycję")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { isPresentingSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Zapisz" : "Dodaj") { Task { await submitSheet() } }
                        .disabled(!canSubmit)
                }
            }
        }
    }

    private var canSubmit: Bool {
        Int(inputProductId) != nil && Double(inputQuantity) != nil && (Double(inputQuantity) ?? 0) > 0
    }

    private func presentAdd() {
        isEditing = false
        inputProductId = ""
        inputQuantity = "1"
        editingProductId = nil
        isPresentingSheet = true
    }

    private func presentEdit(for item: ShoppingListItemDTO) {
        isEditing = true
        inputProductId = String(item.productId)
        inputQuantity = String(item.count)
        editingProductId = item.productId
        isPresentingSheet = true
    }

    private func submitSheet() async {
        guard let pid = Int(inputProductId), let qty = Double(inputQuantity), qty > 0 else { return }
        if isEditing, let original = editingProductId {
            if original != pid {
                await viewModel.deleteItem(productId: original)
                await viewModel.addItem(productId: pid, quantity: qty)
            } else {
                await viewModel.updateItem(productId: pid, quantity: qty)
            }
        } else {
            await viewModel.addItem(productId: pid, quantity: qty)
        }
        await MainActor.run { isPresentingSheet = false }
    }

    // MARK: - Deletion helper
    private func deleteItems(offsets: IndexSet) {
        let ids = offsets.map { viewModel.items[$0].productId }
        Task { for pid in ids { await viewModel.deleteItem(productId: pid) } }
    }
}

#Preview {
    ShoppingListDetailView(ownerId: "00000000-0000-0000-0000-000000000000", shoppingListId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
}
