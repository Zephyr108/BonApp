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

struct NewRecipeProduct: Encodable {
    let product_id: Int
    let quantity: Double
    let unit: String?
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

private struct RecipeCategoryInsert: Encodable {
    let recipe_id: UUID
    let category_id: Int
}

private struct ProductInRecipeInsert: Encodable {
    let recipe_id: UUID
    let product_id: Int
    let quantity: Double
}

final class RecipeViewModel: ObservableObject {
    @Published var recipes: [RecipeDTO] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var myRecipes: [RecipeDTO] = []
    @Published var otherRecipes: [RecipeDTO] = []
    @Published var lastCreatedRecipeId: UUID? = nil

    private let client = SupabaseManager.shared.client
    private let currentUserId: String?

    private func resolveCurrentUserId() async -> String? {
        if let uid = currentUserId, !uid.isEmpty { return uid }
        if let session = try? await client.auth.session { return session.user.id.uuidString }
        return nil
    }

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
            var uid: String? = currentUserId
            if uid == nil {
                if let session = try? await client.auth.session {
                    uid = session.user.id.uuidString
                }
            }

            let publicRows: [RecipeDTO] = try await client
                .from("recipe")
                .select("id,title,description,prepare_time,photo,visibility,user_id")
                .eq("visibility", value: true)
                .order("title", ascending: true)
                .execute()
                .value

            var mineRows: [RecipeDTO] = []
            if let uid = uid, !uid.isEmpty {
                mineRows = try await client
                    .from("recipe")
                    .select("id,title,description,prepare_time,photo,visibility,user_id")
                    .eq("user_id", value: uid)
                    .order("title", ascending: true)
                    .execute()
                    .value
            }

            var merged: [UUID: RecipeDTO] = [:]
            for r in publicRows { merged[r.id] = r }
            for r in mineRows { merged[r.id] = r }
            let result = merged.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

            if let uid = uid, !uid.isEmpty {
                self.myRecipes = result.filter { $0.user_id == uid }
                self.otherRecipes = result.filter { $0.visibility && $0.user_id != uid }
            } else {
                self.myRecipes = []
                self.otherRecipes = result.filter { $0.visibility }
            }

            self.recipes = result
            self.error = nil
        } catch {
            self.error = error.localizedDescription
            self.recipes = []
        }
    }

    // MARK: - Add
    @MainActor
    func addRecipeFull(
        title: String,
        description: String?,
        steps: [String],
        prepare_time: Int,
        imageData: Data?,
        visibility: Bool,
        categoryIds: [Int],
        items: [NewRecipeProduct]
    ) async throws -> UUID {
        guard !isLoading else { throw NSError(domain: "Recipe", code: 1, userInfo: [NSLocalizedDescriptionKey: "Trwa zapisywanie"]) }
        isLoading = true
        error = nil
        defer { isLoading = false }

        // Walidacja
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            let err = "Podaj tytuł przepisu"
            self.error = err
            throw NSError(domain: "Recipe", code: 2, userInfo: [NSLocalizedDescriptionKey: err])
        }
        guard !items.isEmpty else {
            let err = "Dodaj przynajmniej jeden składnik"
            self.error = err
            throw NSError(domain: "Recipe", code: 3, userInfo: [NSLocalizedDescriptionKey: err])
        }

        guard let uid = await resolveCurrentUserId() else {
            let err = "Brak zalogowanego użytkownika"
            self.error = err
            throw NSError(domain: "Recipe", code: 4, userInfo: [NSLocalizedDescriptionKey: err])
        }

        let recipeId = UUID()
        var uploadedPath: String? = nil
        var photoURL: String? = nil

        do {
            // (opcjonalnie) upload zdjęcia – zachowujemy identyczny bucket/nazewnictwo jak w wersji legacy
            if let data = imageData {
                let path = "\(uid)/recipes/\(recipeId).jpg"
                _ = try await client.storage
                    .from("recipe-images")
                    .upload(path, data: data, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true))
                uploadedPath = path
                photoURL = try client.storage.from("recipe-images").getPublicURL(path: path).absoluteString
            }

            // 1) recipe (wraz z steps_list)
            let insert = RecipeInsert(
                id: recipeId,
                title: trimmedTitle,
                description: description ?? "",
                prepare_time: prepare_time,
                photo: photoURL,
                visibility: visibility,
                user_id: uid,
                steps_list: steps
            )
            _ = try await client
                .from("recipe")
                .insert(insert)
                .execute()

            // 2) recipe_category (jeśli wybrano)
            if !categoryIds.isEmpty {
                let catPayload = categoryIds.map { RecipeCategoryInsert(recipe_id: recipeId, category_id: $0) }
                _ = try await client
                    .from("recipe_category")
                    .insert(catPayload)
                    .execute()
            }

            // 3) product_in_recipe (jeśli są składniki)
            if !items.isEmpty {
                let prodPayload = items.map { item in
                    ProductInRecipeInsert(
                        recipe_id: recipeId,
                        product_id: item.product_id,
                        quantity: item.quantity
                    )
                }
                _ = try await client
                    .from("product_in_recipe")
                    .insert(prodPayload)
                    .execute()
            }

            // sukces
            self.lastCreatedRecipeId = recipeId
            await fetchRecipes()
            return recipeId
        } catch {
            // rollback zdjęcia w razie błędu
            if let path = uploadedPath {
                try? await client.storage.from("recipe-images").remove(paths: [path])
            }
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Update
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
                    .from("recipe-images")
                    .upload(path, data: data, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true))
                uploadedPath = path
                let publicURL = try client.storage.from("recipe-images").getPublicURL(path: path).absoluteString
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

            if let uid = currentUserId {
                let path = "\(uid)/recipes/\(id).jpg"
                try? await client.storage.from("recipe-images").remove(paths: [path])
            }

            await fetchRecipes()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Kroki
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

    @MainActor
    func steps(for recipeId: UUID) async -> [RecipeStepDTO] {
        let texts = await rawSteps(for: recipeId)
        return texts.enumerated().map { idx, text in
            RecipeStepDTO(id: UUID(), recipeId: recipeId, order: idx + 1, instruction: text)
        }
    }
}
