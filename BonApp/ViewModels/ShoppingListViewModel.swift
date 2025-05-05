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
    func addItem(name: String, quantity: String, owner: User) {
        let newItem = ShoppingListItem(context: viewContext)
        newItem.name = name
        newItem.quantity = quantity
        newItem.isBought = false
        newItem.owner = owner

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
    /// Marks an item as bought and adds it to the pantry.
    func markAsBought(_ item: ShoppingListItem) {
        item.isBought = true

        // Automatically add to pantry
        let pantryItem = PantryItem(context: viewContext)
        pantryItem.name = item.name
        pantryItem.quantity = item.quantity
        pantryItem.category = "" // Optionally set a default or allow user to edit later
        pantryItem.owner = item.owner

        saveContext()
        fetchItems()
    }

    // MARK: - Helpers
    /// Saves the current context.
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save shopping list context: \(error.localizedDescription)")
        }
    }
}
