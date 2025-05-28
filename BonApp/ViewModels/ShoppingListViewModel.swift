import Foundation
import CoreData

final class ShoppingListViewModel: ObservableObject {
    @Published var items: [ShoppingListItem] = []

    private let viewContext: NSManagedObjectContext

    // MARK: - Inicjalizacja
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
        fetchItems()
    }

    // MARK: - Fetch
    //Pobiera wszystkie rzeczy z sl, sortuje po tym kiedy były kupione potem po nazwie
    func fetchItems() {
        let request: NSFetchRequest<ShoppingListItem> = ShoppingListItem.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ShoppingListItem.isBought, ascending: true),
            NSSortDescriptor(keyPath: \ShoppingListItem.name, ascending: true)
        ]

        do {
            items = try viewContext.fetch(request)
        } catch {
            print("Failed to fetch shopping list items: \(error.localizedDescription)")
            items = []
        }
    }

    // MARK: - Add
    func addItem(name: String, quantity: String, category: String, owner: User) {
        let newItem = ShoppingListItem(context: viewContext)
        newItem.name = name
        newItem.quantity = quantity
        newItem.isBought = false
        newItem.owner = owner
        newItem.category = category

        saveContext()
        fetchItems()
    }

    // MARK: - Update
    func updateItem(_ item: ShoppingListItem, name: String, quantity: String) {
        item.name = name
        item.quantity = quantity

        saveContext()
        fetchItems()
    }

    // MARK: - Delete
    func deleteItem(_ item: ShoppingListItem) {
        viewContext.delete(item)

        saveContext()
        fetchItems()
    }

    // MARK: - Oznacz jako kupione
    func markAsBought(_ item: ShoppingListItem) {
        item.isBought = true
        saveContext()
        fetchItems()
    }

    // MARK: - Helpery
    func saveContext() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
                // Wymuszenie odświeżenia
                fetchItems()
                objectWillChange.send()
            } catch {
                print("Failed to save shopping list context: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Dodaj kupione do spiżarni
    func transferBoughtItemsToPantry(for user: User) {
        let boughtItems = items.filter { $0.isBought && $0.owner == user }

        for item in boughtItems {
            let pantryItem = PantryItem(context: viewContext)
            pantryItem.name = item.name
            pantryItem.quantity = item.quantity
            pantryItem.owner = user
            pantryItem.category = item.category

            viewContext.delete(item)
        }

        saveContext()
        fetchItems()
    }
}
