import SwiftUI
import Supabase

struct ShoppingListView: View {
    @StateObject private var viewModel: ShoppingListViewModel
    @State private var isShowingAdd = false

    init(ownerId: String) {
        _viewModel = StateObject(wrappedValue: ShoppingListViewModel(ownerId: ownerId))
    }


    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.items.indices, id: \.self) { index in
                    let item = viewModel.items[index]
                    HStack {
                        Button(action: {
                            Task { await viewModel.markAsBought(id: item.id) }
                        }) {
                            Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isBought ? .green : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(
                            destination: EditShoppingListItemView(itemId: item.id, productId: item.productId, quantity: item.quantity)
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.productName)
                                    .font(.headline)
                                    .foregroundColor(Color("textPrimary"))
                                Text(String(format: "%.2f", item.quantity))
                                    .font(.subheadline)
                                    .foregroundColor(Color("textSecondary"))
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color("itemsListBackground"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .onDelete(perform: deleteItems)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .background(Color("background").ignoresSafeArea())
            .navigationTitle("Lista zakupów")
            .task { await viewModel.fetchItems() }
            .refreshable { await viewModel.fetchItems() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isShowingAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Dodaj do spiżarni") {
                        Task { await viewModel.transferBoughtItemsToPantry() }
                    }
                    .foregroundColor(Color("buttonText"))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color("edit"))
                    .cornerRadius(8)
                }
            }
            .sheet(isPresented: $isShowingAdd) {
                AddShoppingListItemView { productId, qty in
                    Task {
                        await viewModel.addItem(productId: productId, quantity: qty)
                        isShowingAdd = false
                    }
                }
            }        }
    }

    private func deleteItems(offsets: IndexSet) {
        let ids = offsets.map { viewModel.items[$0].id }
        Task { for id in ids { await viewModel.deleteItem(id: id) } }
    }
}

struct ShoppingListView_Previews: PreviewProvider {
    static var previews: some View {
        ShoppingListView(ownerId: "00000000-0000-0000-0000-000000000000")
    }
}
