import SwiftUI

struct ShoppingListDetailView: View {
    @StateObject private var viewModel: ShoppingListViewModel

    @State private var isPresentingSheet = false

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
                            HStack(alignment: .center, spacing: 12) {
                                Button {
                                    Task {
                                        await viewModel.markAsBought(productId: item.productId)
                                    }
                                } label: {
                                    Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.productName)
                                        .font(.headline)

                                    HStack(spacing: 4) {
                                        Text("Ilość:")
                                            .foregroundColor(.secondary)

                                        Text(String(format: "%.2f", item.quantity))
                                            .foregroundColor(.primary)

                                        if let unit = item.unit, !unit.isEmpty {
                                            Text(unit)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .font(.subheadline)
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteItem(productId: item.productId)
                                    }
                                } label: {
                                    Label("Usuń", systemImage: "trash")
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
                    Button { isPresentingSheet = true } label: { Image(systemName: "plus") }
                }
            }
            .task { await viewModel.fetchItems() }
            .alert(
                isPresented: Binding(
                    get: { viewModel.error != nil },
                    set: { _ in viewModel.error = nil }
                )
            ) {
                Alert(
                    title: Text("Błąd"),
                    message: Text(viewModel.error ?? ""),
                    dismissButton: .default(Text("OK")) {
                        viewModel.error = nil
                    }
                )
            }
            .sheet(isPresented: $isPresentingSheet) {
                AddShoppingListItemView(
                    shoppingListId: shoppingListId,
                    onAdded: {
                        Task { await viewModel.fetchItems() }
                        isPresentingSheet = false
                    }
                )
            }
        }
    }

    // MARK: - Deletion helper
    private func deleteItems(offsets: IndexSet) {
        let ids = offsets.map { viewModel.items[$0].productId }
        Task {
            for pid in ids {
                await viewModel.deleteItem(productId: pid)
            }
        }
    }
}

#Preview {
    ShoppingListDetailView(ownerId: "00000000-0000-0000-0000-000000000000", shoppingListId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
}
