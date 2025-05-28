import Foundation
import CoreData

final class PantryViewModel: ObservableObject {
    @Published var pantryItems: [PantryItem] = []

    private let viewContext: NSManagedObjectContext
    private let user: User

    // MARK: - Inicjalizacja
    init(user: User, context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.user = user
        self.viewContext = context
        fetchPantryItems()
    }

    // MARK: - Fetch
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
    func updateItem(_ item: PantryItem, name: String, quantity: String, category: String) {
        item.name = name
        item.quantity = quantity
        item.category = category

        saveContext()
        fetchPantryItems()
    }

    // MARK: - Delete
    func deleteItem(_ item: PantryItem) {
        viewContext.delete(item)

        saveContext()
        fetchPantryItems()
    }

    //Refresh
    func refresh() {
        fetchPantryItems()
    }

    // MARK: - Helpery
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save pantry changes: \(error.localizedDescription)")
        }
    }
}
