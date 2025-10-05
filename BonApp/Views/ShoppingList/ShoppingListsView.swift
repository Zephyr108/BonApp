import SwiftUI

// MARK: - List of shopping lists (parent screen)
struct ShoppingListsView: View {
    @StateObject private var listsVM: ShoppingListsViewModel
    private let ownerId: String

    init(ownerId: String) {
        self.ownerId = ownerId
        _listsVM = StateObject(wrappedValue: ShoppingListsViewModel(ownerId: ownerId))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(listsVM.lists, id: \.id) { list in
                    NavigationLink(list.name) {
                        ShoppingListDetailView(ownerId: ownerId, shoppingListId: list.id)
                    }
                }
            }
            .navigationTitle("Moje listy zakupów")
            .task { await listsVM.fetchLists() }
            .refreshable { await listsVM.fetchLists() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await listsVM.createList(name: "Nowa lista") } } label: { Image(systemName: "plus") }
                }
            }
        }
    }
}

struct ShoppingListsView_Previews: PreviewProvider {
    static var previews: some View {
        ShoppingListsView(ownerId: "00000000-0000-0000-0000-000000000000")
    }
}
