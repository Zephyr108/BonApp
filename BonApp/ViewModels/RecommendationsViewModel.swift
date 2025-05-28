import Foundation
import CoreData

final class RecommendationsViewModel: ObservableObject {
    @Published var recommendations: [Recipe] = []
    @Published var filterVegetarian: Bool = false
    @Published var filterQuick: Bool = false
    @Published var filterBudget: Bool = false
    @Published var maxMissingIngredients: Int = 3

    private let viewContext: NSManagedObjectContext

    // MARK: - Inicjalizacja
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
    }

    // Pobiera rekomendacje na podstawie produktów w spiżarni
    func fetchRecommendations(for user: User) {
        let pantryItemsSet = (user.pantryItems as? Set<PantryItem>) ?? []
        let pantrySet: Set<String> = Set(pantryItemsSet.compactMap { $0.name })

        //Pobiera publiczne i prywatne (obecnego) przepisy
        let request: NSFetchRequest<Recipe> = Recipe.fetchRequest()
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "isPublic == YES"),
            NSPredicate(format: "author == %@", user)
        ])

        do {
            let allRecipes = try viewContext.fetch(request)
            let filtered = allRecipes.filter { recipe in
                let ingredientsArray = (recipe.ingredients as? [String]) ?? []
                let missing = ingredientsArray.filter { !pantrySet.contains($0) }
                guard missing.count <= maxMissingIngredients else { return false }

                if filterQuick && recipe.cookTime > 30 { return false }

                if filterVegetarian && !(recipe.detail?.localizedCaseInsensitiveContains("wegetari") ?? false) {
                    return false
                }

                if filterBudget && !(recipe.detail?.localizedCaseInsensitiveContains("budżet") ?? false) {
                    return false
                }

                return true
            }
            //Udostępnia rekomendacje
            recommendations = filtered
        } catch {
            print("Failed to fetch recommendations: \(error.localizedDescription)")
            recommendations = []
        }
    }
}

//To do
