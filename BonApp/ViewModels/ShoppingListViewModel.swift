import Foundation
import CoreData

/// ViewModel responsible for managing shopping list items.
final class ShoppingListViewModel: ObservableObject {
    // MARK: - Published properties
    @Published var items: [ShoppingListItem] = []

    // MARK: - Core Data context
    private let viewContext: NSManagedObjectContext

    // MARK: - Initialization
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
        fetchItems()
    }

    // MARK: - Fetch
    /// Fetches all shopping list items, sorted by purchased status then name.
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
    /// Adds a new item to the shopping list.
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
    /// Updates an existing shopping list item.
    func updateItem(_ item: ShoppingListItem, name: String, quantity: String) {
        item.name = name
        item.quantity = quantity

        saveContext()
        fetchItems()
    }

    // MARK: - Delete
    /// Deletes a shopping list item.
    func deleteItem(_ item: ShoppingListItem) {
        viewContext.delete(item)

        saveContext()
        fetchItems()
    }

    // MARK: - Mark as Bought
    /// Marks an item as bought.
    func markAsBought(_ item: ShoppingListItem) {
        item.isBought = true
        saveContext()
        fetchItems()
    }

    // MARK: - Helpers
    /// Saves the current context.
    func saveContext() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
                // Force refresh of published items to reflect UI updates
                fetchItems()
                objectWillChange.send()
            } catch {
                print("Failed to save shopping list context: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Add Bought Items to Pantry
    /// Transfers bought items to pantry and removes them from shopping list.
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
