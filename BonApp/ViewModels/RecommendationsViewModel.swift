import Foundation
import Supabase

// ViewModel for recipe recommendations (Supabase)
final class RecommendationsViewModel: ObservableObject {
    // Filters
    @Published var filterVegetarian: Bool = false
    @Published var filterQuick: Bool = false
    @Published var filterBudget: Bool = false
    @Published var maxMissingIngredients: Int = 3

    // State
    @Published var recommendations: [RecipeItem] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    private let client = SupabaseManager.shared.client

    private struct RecommendationRow: Decodable {
        let id: UUID
        let title: String
        let cook_time: Int
        let image_url: String?
        let is_favorite: Bool?
        let is_public: Bool
        let user_id: String

        enum CodingKeys: String, CodingKey {
            case id, title
            case cook_time
            case image_url
            case is_favorite
            case is_public
            case user_id
        }
    }

    private struct RecommendationsParams: Encodable {
        let p_user_id: String
        let p_max_missing: Int
        let p_quick: Bool
        let p_vegetarian: Bool
        let p_budget: Bool
    }

    // MARK: - Fetch recommendations using RPC
    @MainActor
    func fetchRecommendations(for userId: String?) async {
        guard !isLoading else { return }
        guard let userId else {
            self.error = "Brak zalogowanego użytkownika."
            self.recommendations = []
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let params = RecommendationsParams(
                p_user_id: userId,
                p_max_missing: maxMissingIngredients,
                p_quick: filterQuick,
                p_vegetarian: filterVegetarian,
                p_budget: filterBudget
            )

            let rows: [RecommendationRow] = try await client
                .rpc("get_recommendations", params: params)
                .execute()
                .value

            self.recommendations = rows.map { row in
                RecipeItem(
                    id: row.id,
                    title: row.title,
                    cookTime: row.cook_time,
                    imageURL: row.image_url,
                    isPublic: row.is_public,
                    authorId: row.user_id,
                    isFavorite: row.is_favorite ?? false
                )
            }
        } catch {
            self.error = error.localizedDescription
            self.recommendations = []
        }
    }
}
