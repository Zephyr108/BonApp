import Foundation
import CoreData

/// ViewModel responsible for fetching and managing recipes.
final class RecipeViewModel: ObservableObject {
    // MARK: - Published properties
    @Published var recipes: [Recipe] = []

    // MARK: - Core Data context
    private let viewContext: NSManagedObjectContext

    // MARK: - Initialization
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
        fetchRecipes()
    }

    // MARK: - Fetch
    /// Fetches all recipes sorted by title.
    func fetchRecipes() {
        let request: NSFetchRequest<Recipe> = Recipe.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Recipe.title, ascending: true)
        ]

        do {
            recipes = try viewContext.fetch(request)
        } catch {
            print("Failed to fetch recipes: \(error.localizedDescription)")
            recipes = []
        }
    }

    // MARK: - Add
    /// Adds a new recipe.
    func addRecipe(
        title: String,
        detail: String,
        ingredients: [String],
        cookTime: Int16,
        imageData: Data?,
        isPublic: Bool,
        author: User
    ) {
        let newRecipe = Recipe(context: viewContext)
        newRecipe.title = title
        newRecipe.detail = detail
        newRecipe.ingredients = ingredients as NSArray
        newRecipe.cookTime = cookTime
        newRecipe.isPublic = isPublic
        if let data = imageData {
            newRecipe.images = data
        }
        newRecipe.author = author

        saveContext()
        fetchRecipes()
    }

    // MARK: - Update
    /// Updates an existing recipe.
    func updateRecipe(
        _ recipe: Recipe,
        title: String,
        detail: String,
        ingredients: [String],
        cookTime: Int16,
        imageData: Data?,
        isPublic: Bool
    ) {
        recipe.title = title
        recipe.detail = detail
        recipe.ingredients = ingredients as NSArray
        recipe.cookTime = cookTime
        recipe.isPublic = isPublic
        if let data = imageData {
            recipe.images = data
        }

        saveContext()
        fetchRecipes()
    }

    // MARK: - Delete
    /// Deletes a recipe.
    func deleteRecipe(_ recipe: Recipe) {
        viewContext.delete(recipe)
        saveContext()
        fetchRecipes()
    }

    // MARK: - Helpers
    /// Saves the current context.
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save recipe context: \(error.localizedDescription)")
        }
    }

    // MARK: - Steps

    /// Adds a new step to the given recipe. Step order is computed as existing step count + 1.
    func addStep(_ instruction: String, to recipe: Recipe) {
        let step = RecipeStep(context: viewContext)
        step.instruction = instruction
        // Compute order based on existing steps count
        let existingCount = (recipe.steps as? Set<RecipeStep>)?.count ?? 0
        step.order = Int16(existingCount + 1)
        step.recipe = recipe
        saveContext()
    }

    /// Returns the steps for a recipe, sorted by their order property.
    func steps(for recipe: Recipe) -> [RecipeStep] {
        let set = (recipe.steps as? Set<RecipeStep>) ?? []
        return set.sorted { $0.order < $1.order }
    }
}
