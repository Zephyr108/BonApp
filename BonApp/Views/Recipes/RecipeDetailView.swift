//
//  RecipeDetailView.swift
//  BonApp
//
//

import SwiftUI
import UIKit
import Supabase

// MARK: - DTOs
struct RecipeStepItem: Identifiable, Hashable, Decodable {
    let id: UUID
    let order: Int
    let instruction: String
}

struct RecipeDetailItem: Identifiable, Hashable, Decodable {
    let id: UUID
    let title: String
    let detail: String?
    let cookTime: Int
    let imageURL: String?
    let ingredients: [String]
    let isPublic: Bool
    let userId: String
    let steps: [RecipeStepItem]

    enum CodingKeys: String, CodingKey {
        case id, title
        case detail = "description"
        case cookTime = "prepare_time"
        case imageURL = "photo"
        case isPublic = "visibility"
        case userId = "user_id"
        case stepsList = "steps_list"
    }

    init(id: UUID, title: String, detail: String?, cookTime: Int, imageURL: String?, ingredients: [String], isPublic: Bool, userId: String, steps: [RecipeStepItem]) {
        self.id = id
        self.title = title
        self.detail = detail
        self.cookTime = cookTime
        self.imageURL = imageURL
        self.ingredients = ingredients
        self.isPublic = isPublic
        self.userId = userId
        self.steps = steps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.title = try c.decode(String.self, forKey: .title)
        self.detail = try c.decodeIfPresent(String.self, forKey: .detail)
        self.cookTime = try c.decodeIfPresent(Int.self, forKey: .cookTime) ?? 0
        self.imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        self.isPublic = try c.decodeIfPresent(Bool.self, forKey: .isPublic) ?? true
        self.userId = try c.decodeIfPresent(String.self, forKey: .userId) ?? ""

        self.ingredients = []

        if let stepObjs = try? c.decode([RecipeStepItem].self, forKey: .stepsList) {
            self.steps = stepObjs.sorted { $0.order < $1.order }
        } else if let stepStrings = try? c.decode([String].self, forKey: .stepsList) {
            self.steps = stepStrings.enumerated().map { idx, text in
                RecipeStepItem(id: UUID(), order: idx + 1, instruction: text)
            }
        } else {
            self.steps = []
        }
    }
}

struct IngredientRow: Identifiable, Decodable, Hashable {
    let product_id: Int
    let quantity: Double
    let product: ProductMini
    var id: Int { product_id }

    struct ProductMini: Decodable, Hashable {
        let name: String
        let unit: String?
    }
}

struct CategoryRow: Identifiable, Decodable, Hashable {
    let category: CategoryMini
    var id: String { category.name }
    struct CategoryMini: Decodable, Hashable { let name: String }
}

struct RecipeDetailView: View {
    let recipe: RecipeDetailItem
    @EnvironmentObject var auth: AuthViewModel
    @State private var loadedSteps: [RecipeStepItem] = []
    @State private var loadedIngredients: [IngredientRow] = []
    @State private var loadedCategories: [String] = []

    var body: some View {
        ZStack {
            Color("background").ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let urlString = recipe.imageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty: ProgressView().frame(maxWidth: .infinity)
                            case .success(let image): image.resizable().scaledToFit().cornerRadius(8)
                            case .failure: placeholderImage
                            @unknown default: placeholderImage
                            }
                        }
                    }

                    Text(recipe.title.isEmpty ? "Brak tytułu" : recipe.title)
                        .font(.title)
                        .bold()
                        .foregroundColor(Color("textPrimary"))

                    Text("Czas przygotowania: \(recipe.cookTime) min")
                        .font(.subheadline)
                        .foregroundColor(Color("textSecondary"))

                    if !loadedCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(loadedCategories, id: \.self) { name in
                                    Text(name)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color("textfieldBackground"))
                                        .foregroundColor(Color("textPrimary"))
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }

                    if let detail = recipe.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.body)
                            .foregroundColor(Color("textPrimary"))
                    }

                    Divider()

                    Text("Składniki")
                        .font(.headline)
                        .foregroundColor(Color("textSecondary"))
                    if !loadedIngredients.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(loadedIngredients) { row in
                                let qty = formatQuantity(row.quantity)
                                let unit = formatUnit(row.product.unit)
                                Text("• \(qty) \(unit) \(row.product.name)")
                                    .foregroundColor(Color("textPrimary"))
                            }
                        }
                    } else if !recipe.ingredients.isEmpty {
                        ForEach(recipe.ingredients, id: \.self) { ingredient in
                            Text("• \(ingredient)")
                                .foregroundColor(Color("textPrimary"))
                        }
                    } else {
                        Text("Brak składników")
                            .foregroundColor(Color("textSecondary"))
                    }

                    Divider()

                    Text("Kroki")
                        .font(.headline)
                        .foregroundColor(Color("textSecondary"))

                    let stepsToShow = (loadedSteps.isEmpty ? recipe.steps : loadedSteps)
                        .sorted { $0.order < $1.order }

                    if stepsToShow.isEmpty {
                        Text("Brak kroków")
                            .foregroundColor(Color("textSecondary"))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(stepsToShow) { step in
                                Text("• \(step.instruction)")
                                    .foregroundColor(Color("textPrimary"))
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Szczegóły przepisu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let user = auth.currentUser, user.id == recipe.userId {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: EditRecipeView(
                        recipeId: recipe.id,
                        title: recipe.title,
                        detail: recipe.detail ?? "",
                        ingredients: recipe.ingredients,
                        cookTime: recipe.cookTime,
                        isPublic: recipe.isPublic,
                        steps: recipe.steps.sorted { $0.order < $1.order }.map { $0.instruction },
                        imageURL: recipe.imageURL
                    )) {
                        Text("Edytuj")
                    }
                }
            }
        }
        .task {
            if recipe.steps.isEmpty { await loadStepsFromDB() }
            await loadIngredientsFromDB()
            await loadCategoriesFromDB()
        }
    }

    private func loadStepsFromDB() async {
        do {
            let resp = try await SupabaseManager.shared.client
                .from("recipe")
                .select("steps_list")
                .eq("id", value: recipe.id)
                .single()
                .execute()

            let data = resp.data

            struct StepsObj: Decodable { let steps_list: [RecipeStepItem]? }
            struct StepsStr: Decodable { let steps_list: [String]? }

            if let obj = try? JSONDecoder().decode(StepsObj.self, from: data),
               let arr = obj.steps_list {
                await MainActor.run { self.loadedSteps = arr.sorted { $0.order < $1.order } }
                return
            }
            if let str = try? JSONDecoder().decode(StepsStr.self, from: data),
               let arr = str.steps_list {
                let mapped = arr.enumerated().map { idx, s in
                    RecipeStepItem(id: UUID(), order: idx + 1, instruction: s)
                }
                await MainActor.run { self.loadedSteps = mapped }
            }
        } catch {
            print("[RecipeDetailView] loadStepsFromDB error:", error)
        }
    }

    private func loadIngredientsFromDB() async {
        do {
            let rows: [IngredientRow] = try await SupabaseManager.shared.client
                .from("product_in_recipe")
                .select("product_id, quantity, product:product_id(name,unit)")
                .eq("recipe_id", value: recipe.id)
                .execute()
                .value
            await MainActor.run { self.loadedIngredients = rows }
        } catch {
            print("[RecipeDetailView] loadIngredientsFromDB error:", error)
        }
    }

    private func loadCategoriesFromDB() async {
        do {
            let rows: [CategoryRow] = try await SupabaseManager.shared.client
                .from("recipe_category")
                .select("category:category_id(name)")
                .eq("recipe_id", value: recipe.id)
                .execute()
                .value
            let names = rows.map { $0.category.name }
            await MainActor.run { self.loadedCategories = names }
        } catch {
            print("[RecipeDetailView] loadCategoriesFromDB error:", error)
        }
    }

    private func formatQuantity(_ q: Double) -> String {
        if q.rounded() == q { return String(Int(q)) }
        return String(format: "%.2f", q)
    }

    private func formatUnit(_ u: String?) -> String {
        guard let raw = u?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return "" }
        switch raw.lowercased() {
        case "g", "gram", "grams": return "g"
        case "kg", "kilogram", "kilograms": return "kg"
        case "ml", "milliliter", "milliliters": return "ml"
        case "l", "liter", "liters": return "l"
        case "szt", "szt.", "sztuka", "piece", "pcs": return "szt."
        default: return raw
        }
    }

    private var placeholderImage: some View {
        Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 180).cornerRadius(8)
    }
}

struct RecipeDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sample = RecipeDetailItem(
            id: UUID(),
            title: "Przykładowy przepis",
            detail: "Opis przygotowania krok po kroku.",
            cookTime: 25,
            imageURL: nil,
            ingredients: ["1 jajko", "200g mąki", "100ml mleka"],
            isPublic: true,
            userId: "00000000-0000-0000-0000-000000000000",
            steps: [
                RecipeStepItem(id: UUID(), order: 1, instruction: "Wymieszaj składniki"),
                RecipeStepItem(id: UUID(), order: 2, instruction: "Smaż na patelni")
            ]
        )
        return NavigationStack {
            RecipeDetailView(recipe: sample)
                .environmentObject(AuthViewModel())
        }
    }
}
