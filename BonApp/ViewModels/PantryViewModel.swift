import Foundation
import CoreData

/// ViewModel responsible for managing pantry items.
final class PantryViewModel: ObservableObject {
    // MARK: - Published properties
    @Published var pantryItems: [PantryItem] = []

    // MARK: - Core Data context
    private let viewContext: NSManagedObjectContext
    private let user: User

    // MARK: - Initialization
    init(user: User, context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.user = user
        self.viewContext = context
        fetchPantryItems()
    }

    // MARK: - Fetch
    /// Fetches all pantry items, sorted by category then name.
    func fetchPantryItems() {
        let request: NSFetchRequest<PantryItem> = PantryItem.fetchRequest()
        request.predicate = NSPredicate(format: "owner == %@", user)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PantryItem.category, ascending: true),
            NSSortDescriptor(keyPath: \PantryItem.name, ascending: true)
        ]

        do {
            pantryItems = try viewContext.fetch(request)
        } catch {
            print("Failed to fetch pantry items: \(error.localizedDescription)")
            pantryItems = []
        }
    }

    // MARK: - Add
    /// Adds a new item to the pantry.
    func addItem(name: String, quantity: String, category: String, owner: User) {
        let newItem = PantryItem(context: viewContext)
        newItem.name = name
        newItem.quantity = quantity
        newItem.category = category
        newItem.owner = owner

        saveContext()
        fetchPantryItems()
    }

    // MARK: - Update
    /// Updates an existing pantry item.
    func updateItem(_ item: PantryItem, name: String, quantity: String, category: String) {
        item.name = name
        item.quantity = quantity
        item.category = category

        saveContext()
        fetchPantryItems()
    }

    // MARK: - Delete
    /// Deletes a pantry item.
    func deleteItem(_ item: PantryItem) {
        viewContext.delete(item)

        saveContext()
        fetchPantryItems()
    }

    /// Call this to refresh the pantry items from the store.
    func refresh() {
        fetchPantryItems()
    }

    // MARK: - Helpers
    /// Saves the current context.
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save pantry changes: \(error.localizedDescription)")
        }
    }
}
