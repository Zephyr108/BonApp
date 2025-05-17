import SwiftUI
import CoreData

struct ShoppingListView: View {
    @ObservedObject var user: User
    @StateObject private var viewModel = ShoppingListViewModel()
    @State private var isShowingAdd = false


    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.items.indices, id: \.self) { index in
                    let item = viewModel.items[index]
                    HStack {
                        Button(action: {
                            item.isBought.toggle()
                            viewModel.saveContext()
                        }) {
                            Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isBought ? .green : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(destination: EditShoppingListItemView(item: item)) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.name ?? "")
                                    .font(.headline)
                                    .foregroundColor(Color("textPrimary"))
                                Text(item.quantity ?? "")
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isShowingAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Dodaj do spiżarni") {
                        viewModel.transferBoughtItemsToPantry(for: user)
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
                AddShoppingListItemView { name, quantity, category in
                    viewModel.addItem(name: name, quantity: quantity, category: category, owner: user)
                    isShowingAdd = false
                }
            }        }
    }

    private func deleteItems(offsets: IndexSet) {
        offsets.map { viewModel.items[$0] }.forEach(viewModel.deleteItem)
    }
}

struct ShoppingListView_Previews: PreviewProvider {
    static var previews: some View {
        let user = User(context: PersistenceController.shared.container.viewContext)
        return ShoppingListView(user: user)
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
