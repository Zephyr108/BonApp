import Foundation
import Supabase

// MARK: - DTOs
struct RecipeDTO: Identifiable, Hashable, Decodable {
    let id: UUID
    let title: String
    let detail: String?
    let ingredients: [String]
    let cookTime: Int
    let imageURL: String?
    let isPublic: Bool
    let authorId: String

    enum CodingKeys: String, CodingKey {
        case id, title, detail, ingredients
        case cookTime = "cook_time"
        case imageURL = "image_url"
        case isPublic = "is_public"
        case authorId = "author_id"
    }
}

struct RecipeStepDTO: Identifiable, Hashable, Decodable {
    let id: UUID
    let recipeId: UUID
    let order: Int
    let instruction: String

    enum CodingKeys: String, CodingKey {
        case id, order, instruction
        case recipeId = "recipe_id"
    }
}

private struct RecipeInsert: Encodable {
    let id: UUID
    let title: String
    let detail: String
    let ingredients: [String]
    let cook_time: Int
    let image_url: String?
    let is_public: Bool
    let author_id: String
}

private struct RecipeUpdate: Encodable {
    let title: String
    let detail: String
    let ingredients: [String]
    let cook_time: Int
    let image_url: String?
    let is_public: Bool
}

private struct StepInsert: Encodable {
    let id: UUID
    let recipe_id: UUID
    let order: Int
    let instruction: String
}

final class RecipeViewModel: ObservableObject {
    @Published var recipes: [RecipeDTO] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    private let client = SupabaseManager.shared.client
    private let currentUserId: String?

    // MARK: - Init
    init(currentUserId: String? = nil) {
        self.currentUserId = currentUserId
    }

    // MARK: - Fetch
    @MainActor
    func fetchRecipes() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let rows: [RecipeDTO] = try await client.database
                .from("recipes")
                .select("id,title,detail,ingredients,cook_time,image_url,is_public,author_id")
                .order("title", ascending: true)
                .execute()
                .value

            if let uid = currentUserId {
                // Pokaż moje + publiczne innych
                self.recipes = rows.filter { $0.authorId == uid || $0.isPublic }
            } else {
                // U niezalogowanych pokazujemy tylko publiczne
                self.recipes = rows.filter { $0.isPublic }
            }
        } catch {
            self.error = error.localizedDescription
            self.recipes = []
        }
    }

    // MARK: - Add
    /// Tworzy nowy przepis w Supabase. Jeśli podasz `imageData`, zapisze plik w bucketcie `recipes`.
    func addRecipe(
        title: String,
        detail: String,
        ingredients: [String],
        cookTime: Int,
        imageData: Data?,
        isPublic: Bool,
        authorId: String
    ) async {
        let recipeId = UUID()
        var imageURL: String? = nil
        do {
            // 1) Opcjonalny upload zdjęcia
            if let data = imageData {
                let path = "\(authorId)/recipes/\(recipeId).jpg"
                _ = try await client.storage
                    .from("recipes")
                    .upload(path: path, file: data, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true))
                imageURL = try client.storage.from("recipes").getPublicURL(path: path).absoluteString
            }

            let payload = RecipeInsert(
                id: recipeId,
                title: title,
                detail: detail,
                ingredients: ingredients,
                cook_time: cookTime,
                image_url: imageURL,
                is_public: isPublic,
                author_id: authorId
            )

            _ = try await client.database
                .from("recipes")
                .insert(payload)
                .execute()

            await fetchRecipes()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Update
    /// Aktualizuje przepis; jeśli przekażesz `newImageData`, nadpisze obraz w Storage.
    func updateRecipe(
        id: UUID,
        title: String,
        detail: String,
        ingredients: [String],
        cookTime: Int,
        newImageData: Data?,
        isPublic: Bool,
        authorId: String
    ) async {
        do {
            var imageURL: String? = nil
            if let data = newImageData {
                let path = "\(authorId)/recipes/\(id).jpg"
                _ = try await client.storage
                    .from("recipes")
                    .upload(path: path, file: data, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true))
                imageURL = try client.storage.from("recipes").getPublicURL(path: path).absoluteString
            }

            let updatePayload = RecipeUpdate(
                title: title,
                detail: detail,
                ingredients: ingredients,
                cook_time: cookTime,
                image_url: imageURL,
                is_public: isPublic
            )

            _ = try await client.database
                .from("recipes")
                .update(updatePayload)
                .eq("id", value: id)
                .execute()

            await fetchRecipes()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Delete
    func deleteRecipe(id: UUID) async {
        do {
            // Usuń kroki (jeśli nie masz kaskady w DB)
            _ = try? await client.database
                .from("recipe_steps")
                .delete()
                .eq("recipe_id", value: id)
                .execute()

            _ = try await client.database
                .from("recipes")
                .delete()
                .eq("id", value: id)
                .execute()

            await fetchRecipes()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Kroki
    /// Dodaje krok do przepisu. Ustala `order` jako (max(order) + 1).
    func addStep(_ instruction: String, to recipeId: UUID) async {
        do {
            struct OrderRow: Decodable { let order: Int }
            let rows: [OrderRow] = try await client.database
                .from("recipe_steps")
                .select("order")
                .eq("recipe_id", value: recipeId)
                .order("order", ascending: false)
                .limit(1)
                .execute()
                .value
            let next = (rows.first?.order ?? 0) + 1

            let payload = StepInsert(
                id: UUID(),
                recipe_id: recipeId,
                order: next,
                instruction: instruction
            )
            _ = try await client.database
                .from("recipe_steps")
                .insert(payload)
                .execute()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    /// Zwraca kroki przepisu posortowane po `order`.
    @MainActor
    func steps(for recipeId: UUID) async -> [RecipeStepDTO] {
        do {
            let rows: [RecipeStepDTO] = try await client.database
                .from("recipe_steps")
                .select("id,recipe_id,order,instruction")
                .eq("recipe_id", value: recipeId)
                .order("order", ascending: true)
                .execute()
                .value
            return rows
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }
}
