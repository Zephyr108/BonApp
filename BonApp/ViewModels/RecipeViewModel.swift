import Foundation
import CoreData

final class RecipeViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []

    private let viewContext: NSManagedObjectContext

    // MARK: - Inicjalizacja
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
        fetchRecipes()
    }

    // MARK: - Fetch
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
    func deleteRecipe(_ recipe: Recipe) {
        viewContext.delete(recipe)
        saveContext()
        fetchRecipes()
    }

    // MARK: - Helpery
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save recipe context: \(error.localizedDescription)")
        }
    }

    // MARK: - Kroki

    //Dodaje krok, kolejność +1
    func addStep(_ instruction: String, to recipe: Recipe) {
        let step = RecipeStep(context: viewContext)
        step.instruction = instruction
        //Ustawia kolejność na podstawie ilości kroków
        let existingCount = (recipe.steps as? Set<RecipeStep>)?.count ?? 0
        step.order = Int16(existingCount + 1)
        step.recipe = recipe
        saveContext()
    }

    //Zwraca kroki po kolejności
    func steps(for recipe: Recipe) -> [RecipeStep] {
        let set = (recipe.steps as? Set<RecipeStep>) ?? []
        return set.sorted { $0.order < $1.order }
    }
}
