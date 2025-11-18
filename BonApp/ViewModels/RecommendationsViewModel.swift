import Foundation
import Supabase

final class RecommendationsViewModel: ObservableObject {

    struct RecommendedRecipe: Identifiable, Equatable {
        let id: UUID
        let title: String
        let cookTime: Int
        let imageURL: String?
        let isPublic: Bool
        let authorId: String
        let isFavorite: Bool
        let categories: [String]
        let ingredientProductIds: [Int]
    }

    // MARK: - Wyniki rekomendacji
    @Published var recommendedByPreferences: [RecommendedRecipe] = []
    @Published var recommendedByPantry: [RecommendedRecipe] = []

    @Published var isLoading: Bool = false
    @Published var error: String?

    private let client = SupabaseManager.shared.client

    @MainActor
    func fetchRecommendations(for userId: UUID?) async {
        await refresh(userId: userId?.uuidString)
    }

    // MARK: - Public API
    @MainActor
    func refresh(userId: String?) async {
        guard let userId else {
            self.error = "Brak zalogowanego użytkownika."
            self.recommendedByPreferences = []
            self.recommendedByPantry = []
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let prefs: [String] = try await fetchUserPreferences(userId: userId)

            let allRecipes = try await fetchAllRecipes(userId: userId)

            let pantry = try await fetchPantry(userId: userId)

            self.recommendedByPreferences = filterByPreferences(recipes: allRecipes, preferences: prefs)
            self.recommendedByPantry = filterByPantry(recipes: allRecipes, pantry: pantry)

        } catch {
            self.error = error.localizedDescription
            self.recommendedByPreferences = []
            self.recommendedByPantry = []
        }
    }

    // MARK: - Fetching

    private func fetchUserPreferences(userId: String) async throws -> [String] {
        struct UserRow: Decodable {
            let preferences: [String]?
        }

        let rows: [UserRow] = try await client
            .from("users")
            .select("preferences")
            .eq("id", value: userId)
            .execute()
            .value

        return rows.first?.preferences ?? []
    }

    private func fetchAllRecipes(userId: String) async throws -> [RecommendedRecipe] {
        struct RecipeRow: Decodable {
            let id: UUID
            let title: String
            let prepare_time: Int?
            let photo: String?
            let visibility: Bool
            let user_id: UUID
        }

        struct RecipeCategoryRow: Decodable {
            let recipe_id: UUID
            let category: CategoryRow
        }

        struct CategoryRow: Decodable { let name: String }

        struct IngredientRow: Decodable {
            let recipe_id: UUID
            let product_id: Int
        }

        let recipeRows: [RecipeRow] = try await client
            .from("recipe")
            .select("id, title, prepare_time, photo, visibility, user_id")
            .order("title", ascending: true)
            .execute()
            .value

        let visibleRows = recipeRows.filter { $0.visibility || $0.user_id.uuidString == userId }

        let categoryRows: [RecipeCategoryRow] = try await client
            .from("recipe_category")
            .select("recipe_id, category(name)")
            .execute()
            .value

        var categoriesByRecipe: [UUID: [String]] = [:]
        for row in categoryRows {
            categoriesByRecipe[row.recipe_id, default: []].append(row.category.name)
        }

        let ingredientRows: [IngredientRow] = try await client
            .from("product_in_recipe")
            .select("recipe_id, product_id")
            .execute()
            .value

        var ingredientsByRecipe: [UUID: [Int]] = [:]
        for row in ingredientRows {
            ingredientsByRecipe[row.recipe_id, default: []].append(row.product_id)
        }

        return visibleRows.map { r in
            RecommendedRecipe(
                id: r.id,
                title: r.title,
                cookTime: r.prepare_time ?? 0,
                imageURL: r.photo,
                isPublic: r.visibility,
                authorId: r.user_id.uuidString,
                isFavorite: false,
                categories: categoriesByRecipe[r.id] ?? [],
                ingredientProductIds: ingredientsByRecipe[r.id] ?? []
            )
        }
    }

    private func fetchPantry(userId: String) async throws -> [Int: Double] {
        struct PantryRow: Decodable {
            let product_id: Int
            let quantity: Double
        }

        let rows: [PantryRow] = try await client
            .from("pantry")
            .select("product_id, quantity")
            .eq("user_id", value: userId)
            .execute()
            .value

        var dict: [Int: Double] = [:]
        for row in rows {
            dict[row.product_id] = row.quantity
        }
        return dict
    }

    // MARK: - Filtering

    private func filterByPreferences(recipes: [RecommendedRecipe], preferences: [String]) -> [RecommendedRecipe] {
        guard !preferences.isEmpty else { return [] }
        return recipes.filter { recipe in
            !Set(recipe.categories).intersection(preferences).isEmpty
        }
    }

    private func filterByPantry(recipes: [RecommendedRecipe], pantry: [Int: Double]) -> [RecommendedRecipe] {
        recipes.filter { recipe in
            guard !recipe.ingredientProductIds.isEmpty else { return false }

            let total = recipe.ingredientProductIds.count
            let owned = recipe.ingredientProductIds.filter { pantry[$0] != nil }.count

            return Double(owned) / Double(total) >= 0.5
        }
    }
    var hasNoRecommendations: Bool {
        recommendedByPreferences.isEmpty && recommendedByPantry.isEmpty
    }
}
