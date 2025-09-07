import Foundation
import Supabase

// MARK: - DTOs
struct RecipeDTO: Identifiable, Hashable, Decodable {
    let id: UUID
    let title: String
    let description: String?
    let prepare_time: Int
    let photo: String?
    let visibility: Bool
    let user_id: String

    enum CodingKeys: String, CodingKey {
        case id, title, description, prepare_time, photo, visibility, user_id
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
    let description: String
    let prepare_time: Int
    let photo: String?
    let visibility: Bool
    let user_id: String
}

private struct RecipeUpdate: Encodable {
    let description: String
    let prepare_time: Int
    let photo: String?
    let visibility: Bool
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
                .from("recipe")
                .select("id,title,description,prepare_time,photo,visibility,user_id")
                .order("title", ascending: true)
                .execute()
                .value

            if let uid = currentUserId {
                // Pokaż moje + publiczne innych
                self.recipes = rows.filter { $0.user_id == uid || $0.visibility }
            } else {
                // U niezalogowanych pokazujemy tylko publiczne
                self.recipes = rows.filter { $0.visibility }
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
        description: String,
        _ ingredients: [String] = [],
        prepare_time: Int,
        imageData: Data?,
        visibility: Bool,
        user_id: String
    ) async {
        let recipeId = UUID()
        var photo: String? = nil
        do {
            // 1) Opcjonalny upload zdjęcia
            if let data = imageData {
                let path = "\(user_id)/recipes/\(recipeId).jpg"
                _ = try await client.storage
                    .from("recipes")
                    .upload(path: path, file: data, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true))
                photo = try client.storage.from("recipes").getPublicURL(path: path).absoluteString
            }

            let payload = RecipeInsert(
                id: recipeId,
                title: title,
                description: description,
                prepare_time: prepare_time,
                photo: photo,
                visibility: visibility,
                user_id: user_id
            )

            _ = try await client.database
                .from("recipe")
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
        description: String,
        _ ingredients: [String] = [],
        prepare_time: Int,
        newImageData: Data?,
        visibility: Bool,
        user_id: String
    ) async {
        do {
            var photo: String? = nil
            if let data = newImageData {
                let path = "\(user_id)/recipes/\(id).jpg"
                _ = try await client.storage
                    .from("recipes")
                    .upload(path: path, file: data, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true))
                photo = try client.storage.from("recipes").getPublicURL(path: path).absoluteString
            }

            let updatePayload = RecipeUpdate(
                description: description,
                prepare_time: prepare_time,
                photo: photo,
                visibility: visibility
            )

            _ = try await client.database
                .from("recipe")
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
            _ = try await client.database
                .from("recipe")
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
            struct StepsRow: Decodable { let steps_list: [String]? }
            // 1) Load current steps
            let rows: [StepsRow] = try await client.database
                .from("recipe")
                .select("steps_list")
                .eq("id", value: recipeId)
                .limit(1)
                .execute()
                .value
            var steps = rows.first?.steps_list ?? []
            steps.append(instruction)

            struct StepsUpdate: Encodable { let steps_list: [String] }
            let payload = StepsUpdate(steps_list: steps)

            _ = try await client.database
                .from("recipe")
                .update(payload)
                .eq("id", value: recipeId)
                .execute()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    /// Zwraca kroki przepisu posortowane po `order`.
    @MainActor
    func steps(for recipeId: UUID) async -> [RecipeStepDTO] {
        do {
            struct StepsRow: Decodable { let steps_list: [String]? }
            let rows: [StepsRow] = try await client.database
                .from("recipe")
                .select("steps_list")
                .eq("id", value: recipeId)
                .limit(1)
                .execute()
                .value
            let steps = rows.first?.steps_list ?? []
            return steps.enumerated().map { idx, text in
                RecipeStepDTO(id: UUID(), recipeId: recipeId, order: idx + 1, instruction: text)
            }
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }
}
