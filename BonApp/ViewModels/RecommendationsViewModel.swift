import Foundation
import CoreData

/// ViewModel for generating recipe recommendations based on pantry contents.
final class RecommendationsViewModel: ObservableObject {
    // MARK: - Published properties
    @Published var recommendations: [Recipe] = []
    @Published var filterVegetarian: Bool = false
    @Published var filterQuick: Bool = false
    @Published var filterBudget: Bool = false
    @Published var maxMissingIngredients: Int = 3

    // MARK: - Core Data context
    private let viewContext: NSManagedObjectContext

    // MARK: - Initialization
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
    }

    /// Fetches recommended recipes for the given user based on available pantry items and optional filters.
    func fetchRecommendations(for user: User) {
        // Safely unwrap the user's pantry items and extract names
        let pantryItemsSet = (user.pantryItems as? Set<PantryItem>) ?? []
        let pantrySet: Set<String> = Set(pantryItemsSet.compactMap { $0.name })

        // Fetch all public recipes and the user's own private recipes
        let request: NSFetchRequest<Recipe> = Recipe.fetchRequest()
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "isPublic == YES"),
            NSPredicate(format: "author == %@", user)
        ])

        do {
            let allRecipes = try viewContext.fetch(request)
            let filtered = allRecipes.filter { recipe in
                // Safely unwrap and cast recipe.ingredients to [String]
                let ingredientsArray = (recipe.ingredients as? [String]) ?? []
                let missing = ingredientsArray.filter { !pantrySet.contains($0) }
                guard missing.count <= maxMissingIngredients else { return false }

                // Apply quick filter (e.g., cookTime <= 30)
                if filterQuick && recipe.cookTime > 30 { return false }

                // Apply vegetarian filter (check for keyword in detail)
                if filterVegetarian && !(recipe.detail?.localizedCaseInsensitiveContains("wegetari") ?? false) {
                    return false
                }

                // Apply budget filter (check for keyword in detail)
                if filterBudget && !(recipe.detail?.localizedCaseInsensitiveContains("budżet") ?? false) {
                    return false
                }

                return true
            }
            // Publish recommendations
            recommendations = filtered
        } catch {
            print("Failed to fetch recommendations: \(error.localizedDescription)")
            recommendations = []
        }
    }
}
