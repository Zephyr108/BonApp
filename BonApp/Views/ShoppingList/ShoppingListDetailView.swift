import SwiftUI

struct ShoppingListDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ShoppingListViewModel
    @State private var editingItem: ShoppingListItemDTO? = nil


    private let ownerId: String
    private let shoppingListId: UUID
    private let listName: String

    init(ownerId: String, shoppingListId: UUID, listName: String = "Lista zakupów") {
        _viewModel = StateObject(wrappedValue: ShoppingListViewModel(ownerId: ownerId, shoppingListId: shoppingListId))
        self.ownerId = ownerId
        self.shoppingListId = shoppingListId
        self.listName = listName
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("background")
                    .ignoresSafeArea()
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
                                .onLongPressGesture {
                                    editingItem = item
                                }
                            }
                            .onDelete(perform: deleteItems)
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    }
                }
                .navigationTitle(listName)
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
                        NavigationLink {
                            AddShoppingListItemView(
                                shoppingListId: shoppingListId,
                                onAdded: {
                                    Task { await viewModel.fetchItems() }
                                }
                            )
                        } label: {
                            Image(systemName: "plus")
                        }
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
                .sheet(item: $editingItem) { item in
                    EditShoppingListItemView(
                        shoppingListId: shoppingListId,
                        productId: item.productId,
                        productName: item.productName,
                        quantity: item.quantity
                    )
                }
                .onChange(of: editingItem) { oldValue, newValue in
                    if newValue == nil {
                        Task {
                            await viewModel.fetchItems()
                        }
                    }
                }
                
                if viewModel.shouldAskToDeleteList {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        Text("Wszystkie produkty z listy zostały kupione i już są w spiżarni.")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text("Czy usunąć listę zakupową?")
                            .font(.subheadline)
                            .foregroundColor(Color("textSecondary"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            Button {
                                withAnimation {
                                    viewModel.shouldAskToDeleteList = false
                                }
                            } label: {
                                Text("Anuluj")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color("textfieldBackground"))
                                    .foregroundColor(Color("textPrimary"))
                                    .cornerRadius(16)
                            }

                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteCurrentList()
                                    await MainActor.run {
                                        withAnimation {
                                            viewModel.shouldAskToDeleteList = false
                                            dismiss()
                                        }
                                    }
                                }
                            } label: {
                                Text("Tak")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color("cancel"))
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(24)
                    .background(Color("background"))
                    .cornerRadius(28)
                    .shadow(radius: 20)
                    .padding(.horizontal, 32)
                }
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
