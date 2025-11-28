//
//  RecipeListViewModel.swift
//  BonApp
//
//  Created by Marcin on 20/10/2025.
//

import Foundation
import Supabase

@MainActor
final class RecipeListViewModel: ObservableObject {
    @Published var myRecipes: [RecipeListItem] = []
    @Published var otherRecipes: [RecipeListItem] = []
    @Published var favorites: Set<UUID> = []
    @Published var isLoading = false
    @Published var error: String?

    private let client = SupabaseManager.shared.client

    func refresh(currentUserId: String?) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            var effectiveUid: String? = currentUserId
            if effectiveUid == nil {
                if let session = try? await client.auth.session {
                    effectiveUid = session.user.id.uuidString
                }
            }

            let publicRows: [RecipeListItem] = try await client
                .from("recipe")
                .select("id,title,description,prepare_time,photo,visibility,user_id")
                .eq("visibility", value: true)
                .order("title", ascending: true)
                .execute()
                .value

            var mineRows: [RecipeListItem] = []
            if let uid = effectiveUid, !uid.isEmpty {
                mineRows = try await client
                    .from("recipe")
                    .select("id,title,description,prepare_time,photo,visibility,user_id")
                    .eq("user_id", value: uid)
                    .order("title", ascending: true)
                    .execute()
                    .value
            }

            var dict: [UUID: RecipeListItem] = [:]
            for r in publicRows { dict[r.id] = r }
            for r in mineRows { dict[r.id] = r }
            let rows = dict.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

            if let uid = effectiveUid, !uid.isEmpty {
                let u = uid.lowercased()
                self.myRecipes = rows.filter { $0.authorId.lowercased() == u }
                self.otherRecipes = rows.filter { $0.isPublic && $0.authorId.lowercased() != u }
                //#if DEBUG
                //print("recipes: total=\(rows.count), mine=\(self.myRecipes.count), others=\(self.otherRecipes.count)")
                //#endif

                struct FavRow: Decodable { let recipe_id: UUID }
                let favRows: [FavRow] = try await client
                    .from("favorite_recipe")
                    .select("recipe_id")
                    .eq("user_id", value: uid)
                    .execute()
                    .value
                self.favorites = Set(favRows.map { $0.recipe_id })
            } else {
                self.myRecipes = []
                self.otherRecipes = rows.filter { $0.isPublic }
                self.favorites = []
            }
        } catch {
            self.error = error.localizedDescription
            self.myRecipes = []
            self.otherRecipes = []
        }
    }

    // MARK: - Akcje
    func deleteRecipe(_ id: UUID) async {
        do {
            _ = try await client.from("recipe").delete().eq("id", value: id).execute()
            _ = try? await client.from("recipe_steps").delete().eq("recipe_id", value: id).execute()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleFavorite(userId: String, recipeId: UUID) async {
        if favorites.contains(recipeId) {
            do {
                _ = try await client
                    .from("favorite_recipe")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("recipe_id", value: recipeId)
                    .execute()
                favorites.remove(recipeId)
            } catch {
                self.error = error.localizedDescription
            }
        } else {
            do {
                struct FavoriteInsert: Encodable { let user_id: String; let recipe_id: UUID }
                let payload = FavoriteInsert(user_id: userId, recipe_id: recipeId)
                _ = try await client.from("favorite_recipe").insert(payload).execute()
                favorites.insert(recipeId)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
