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
    let steps_list: [String]?
}

private struct RecipeUpdate: Encodable {
    let description: String
    let prepare_time: Int
    let photo: String?
    let visibility: Bool
}

private struct RecipeUpdateNoPhoto: Encodable {
    let description: String
    let prepare_time: Int
    let visibility: Bool
}

private struct RecipeUpdateWithPhoto: Encodable {
    let description: String
    let prepare_time: Int
    let photo: String
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
            let rows: [RecipeDTO] = try await client
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
    @MainActor
    func addRecipe(
        title: String,
        description: String,
        _ ingredients: [String] = [],
        prepare_time: Int,
        imageData: Data?,
        visibility: Bool,
        user_id: String
    ) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        let recipeId = UUID()
        var uploadedPath: String? = nil
        var photoURL: String? = nil

        do {
            // 1) Optional image upload
            if let data = imageData {
                let path = "\(user_id)/recipes/\(recipeId).jpg"
                _ = try await client.storage
                    .from("recipes")
                    .upload(path, data: data, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true))
                uploadedPath = path
                photoURL = try client.storage.from("recipes").getPublicURL(path: path).absoluteString
            }

            // 2) Insert row
            let payload = RecipeInsert(
                id: recipeId,
                title: title,
                description: description,
                prepare_time: prepare_time,
                photo: photoURL,
                visibility: visibility,
                user_id: user_id,
                steps_list: []
            )

            _ = try await client
                .from("recipe")
                .insert(payload)
                .execute()

            await fetchRecipes()
        } catch {
            // If DB insert failed but we already uploaded image, try to remove the orphan file
            if let path = uploadedPath {
                try? await client.storage.from("recipes").remove(paths: [path])
            }
            self.error = error.localizedDescription
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
            var payloadNoPhoto: RecipeUpdateNoPhoto? = nil
            var payloadWithPhoto: RecipeUpdateWithPhoto? = nil
            var uploadedPath: String? = nil

            if let data = newImageData {
                let path = "\(user_id)/recipes/\(id).jpg"
                _ = try await client.storage
                    .from("recipes")
                    .upload(path, data: data, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true))
                uploadedPath = path
                let publicURL = try client.storage.from("recipes").getPublicURL(path: path).absoluteString
                payloadWithPhoto = RecipeUpdateWithPhoto(
                    description: description,
                    prepare_time: prepare_time,
                    photo: publicURL,
                    visibility: visibility
                )
            } else {
                payloadNoPhoto = RecipeUpdateNoPhoto(
                    description: description,
                    prepare_time: prepare_time,
                    visibility: visibility
                )
            }

            if let p = payloadWithPhoto {
                _ = try await client
                    .from("recipe")
                    .update(p)
                    .eq("id", value: id)
                    .execute()
            } else if let p = payloadNoPhoto {
                _ = try await client
                    .from("recipe")
                    .update(p)
                    .eq("id", value: id)
                    .execute()
            }

            await fetchRecipes()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Delete
    func deleteRecipe(id: UUID) async {
        do {
            _ = try await client
                .from("recipe")
                .delete()
                .eq("id", value: id)
                .execute()

            // Best-effort: remove possible image file with known pattern
            // (ignores errors if file doesn't exist)
            if let uid = currentUserId {
                let path = "\(uid)/recipes/\(id).jpg"
                try? await client.storage.from("recipes").remove(paths: [path])
            }

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
            let rows: [StepsRow] = try await client
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

            _ = try await client
                .from("recipe")
                .update(payload)
                .eq("id", value: recipeId)
                .execute()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    /// Zwraca surową listę kroków dokładnie tak, jak jest zapisana w kolumnie `steps_list` (JSONB array of strings).
    @MainActor
    func rawSteps(for recipeId: UUID) async -> [String] {
        do {
            struct StepsRow: Decodable { let steps_list: [String]? }
            let row: StepsRow = try await client
                .from("recipe")
                .select("steps_list")
                .eq("id", value: recipeId)
                .single()
                .execute()
                .value
            return row.steps_list ?? []
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    /// Zwraca kroki przepisu posortowane po `order`.
    @MainActor
    func steps(for recipeId: UUID) async -> [RecipeStepDTO] {
        let texts = await rawSteps(for: recipeId)
        return texts.enumerated().map { idx, text in
            RecipeStepDTO(id: UUID(), recipeId: recipeId, order: idx + 1, instruction: text)
        }
    }
}
