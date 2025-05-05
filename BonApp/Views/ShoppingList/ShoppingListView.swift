import SwiftUI
import CoreData

struct ShoppingListView: View {
    @ObservedObject var user: User
    @StateObject private var viewModel = ShoppingListViewModel()
    @State private var isShowingAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.items, id: \.self) { item in
                    HStack {
                        Button(action: {
                            viewModel.markAsBought(item)
                        }) {
                            Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isBought ? .green : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        NavigationLink(destination: EditShoppingListItemView(item: item)) {
                            VStack(alignment: .leading) {
                                Text(item.name ?? "")
                                Text(item.quantity ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Lista zakupów")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isShowingAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAdd) {
                AddShoppingListItemView { name, quantity in
                    // Provide the current user from environment or context
                    viewModel.addItem(name: name, quantity: quantity, owner: user)
                    isShowingAdd = false
                }
            }
        }
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
