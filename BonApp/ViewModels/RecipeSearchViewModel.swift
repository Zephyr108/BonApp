//
//  RecipeSearchViewModel.swift
//  BonApp
//
//  Created by Marcin on 20/11/2025.
//

import Foundation
import Supabase

struct SearchRecipeItem: Identifiable, Hashable, Decodable {
    let id: UUID
    let title: String
    let description: String?
    let cookTime: Int
    let imageURL: String?
    let isPublic: Bool
    let userId: String

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case cookTime = "prepare_time"
        case imageURL = "photo"
        case isPublic = "visibility"
        case userId = "user_id"
    }
}

@MainActor
final class RecipeSearchViewModel: ObservableObject {
    @Published var results: [SearchRecipeItem] = []
    @Published var favorites: Set<UUID> = []
    @Published var isLoading = false
    @Published var error: String? = nil

    @Published var allCategories: [String] = []
    @Published var selectedCategories: Set<String> = []

    init() {
        Task {
            await loadCategories()
        }
    }

    private let client = SupabaseManager.shared.client

    func loadCategories() async {
        do {
            struct CategoryRow: Decodable { let name: String }

            let rows: [CategoryRow] = try await client
                .from("category")
                .select("name")
                .order("name", ascending: true)
                .execute()
                .value

            allCategories = rows.map { $0.name }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func search(
        query: String,
        maxCookTime: Int,
        showOnlyFavorites: Bool,
        categories: Set<String>,
        currentUserId: String?
    ) async {

        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            var favIds: [UUID] = []
            if let uid = currentUserId {
                struct FavRow: Decodable { let recipe_id: UUID }
                let favRows: [FavRow] = try await client
                    .from("favorite_recipe")
                    .select("recipe_id")
                    .eq("user_id", value: uid)
                    .execute()
                    .value

                favIds = favRows.map { $0.recipe_id }
                favorites = Set(favIds)
            } else {
                favorites = []
            }

            var rq = client
                .from("recipe")
                .select("id,title,description,prepare_time,photo,visibility,user_id")

            rq = rq.lte("prepare_time", value: maxCookTime)

            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                rq = rq.ilike("title", pattern: "%\(trimmed)%")
            }

            if showOnlyFavorites, !favIds.isEmpty {
                rq = rq.in("id", values: favIds)
            }

            if !categories.isEmpty {
                struct CategoryRow: Decodable { let id: Int; let name: String }

                let categoryRows: [CategoryRow] = try await client
                    .from("category")
                    .select("id,name")
                    .in("name", values: Array(categories))
                    .execute()
                    .value

                let categoryIds = categoryRows.map { $0.id }

                if !categoryIds.isEmpty {
                    struct RCRow: Decodable { let recipe_id: UUID }

                    let rcRows: [RCRow] = try await client
                        .from("recipe_category")
                        .select("recipe_id")
                        .in("category_id", values: categoryIds)
                        .execute()
                        .value

                    let recipeIds = rcRows.map { $0.recipe_id }

                    if !recipeIds.isEmpty {
                        rq = rq.in("id", values: recipeIds)
                    } else {
                        results = []
                        return
                    }
                } else {
                    results = []
                    return
                }
            }

            let rows: [SearchRecipeItem] = try await rq
                .order("title", ascending: true)
                .execute()
                .value

            if let uid = currentUserId {
                results = rows.filter { $0.userId == uid || $0.isPublic }
            } else {
                results = rows.filter { $0.isPublic }
            }

        } catch {
            self.error = error.localizedDescription
        }
    }
}
