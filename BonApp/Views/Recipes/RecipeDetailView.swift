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

private struct FavoriteRow: Decodable, Hashable {
    let id: UUID
}

struct RecipeDetailView: View {
    let recipe: RecipeDetailItem
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var recipeVM = RecipeViewModel()
    @State private var ingredientAvailability: [IngredientAvailability] = []
    @State private var isCreatingShoppingList: Bool = false
    @State private var loadedSteps: [RecipeStepItem] = []
    @State private var loadedIngredients: [IngredientRow] = []
    @State private var loadedCategories: [String] = []
    @State private var isFavorite: Bool = false
    @State private var favoriteMessage: String? = nil
    @State private var showExecuteAlert: Bool = false
    @State private var executeMessage: String? = nil

    private var hasMissingIngredients: Bool {
        ingredientAvailability.contains { !$0.isAvailable }
    }

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
                    if !ingredientAvailability.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(ingredientAvailability) { item in
                                let required = formatQuantity(item.requiredQuantity)
                                let unit = formatUnit(item.unit)
                                let available = formatQuantity(item.inPantryQuantity)

                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Image(systemName: item.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(item.isAvailable ? .green : .red)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(required) \(unit) \(item.name)")
                                            .foregroundColor(Color("textPrimary"))
                                        Text("W spiżarni: \(available) \(unit)")
                                            .font(.caption)
                                            .foregroundColor(Color("textSecondary"))
                                    }

                                    Spacer()
                                }
                            }
                        }
                    } else if !loadedIngredients.isEmpty {
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
                    
                    if hasMissingIngredients {
                        Button {
                            Task {
                                isCreatingShoppingList = true
                                defer { isCreatingShoppingList = false }
                                do {
                                    let result = try await recipeVM.createShoppingListForMissingItems(
                                        recipeId: recipe.id,
                                        recipeTitle: recipe.title.isEmpty ? "Lista zakupów" : recipe.title
                                    )

                                    await MainActor.run {
                                        switch result {
                                        case .created:
                                            favoriteMessage = "Lista zakupów została utworzona!"
                                        case .alreadyExists:
                                            favoriteMessage = "Taka lista zakupów już istnieje."
                                        case .noMissing:
                                            favoriteMessage = "Masz już wszystkie składniki w spiżarni."
                                        }
                                    }

                                    Task {
                                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                                        await MainActor.run {
                                            favoriteMessage = nil
                                        }
                                    }
                                } catch {
                                    print("[RecipeDetailView] createShoppingListForMissingItems error:", error)
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "cart.badge.plus")
                                Text("Dodaj brakujące produkty do listy zakupów")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color("itemsListBackground"))
                            .foregroundColor(Color("textPrimary"))
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            .padding(.top, 16)
                        }
                        .disabled(isCreatingShoppingList)
                    }

                    if !hasMissingIngredients {
                        Button {
                            showExecuteAlert = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Wykonaj przepis!")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color("addActive"))
                            .foregroundColor(Color("buttonText"))
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            .padding(.top, 8)
                        }
                    }
                    
                    if let user = auth.currentUser, user.id == recipe.userId {
                        NavigationLink(destination: EditRecipeView(
                            recipeId: recipe.id,
                            title: recipe.title,
                            detail: recipe.detail ?? "",
                            cookTime: recipe.cookTime,
                            isPublic: recipe.isPublic,
                            steps: recipe.steps.map { $0.instruction },
                            imageURL: recipe.imageURL
                        )) {
                            Text("Edytuj przepis")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color("edit"))
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                .padding(.top, 24)
                                .padding(.bottom, 8)
                        }
                    }
                }
                .padding()
            }
        }
        .overlay(alignment: .top) {
            if let message = favoriteMessage {
                Text(message)
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 4)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        
        .overlay(alignment: .bottom) {
            if let msg = executeMessage {
                Text(msg)
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 4)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }

        .alert("Wykonać przepis?", isPresented: $showExecuteAlert) {
            Button("Anuluj", role: .cancel) { }
            Button("Tak", role: .destructive) {
                Task {
                    let result = await recipeVM.executeRecipe(recipeId: recipe.id)
                    await loadIngredientsAvailability()

                    await MainActor.run {
                        switch result {
                        case .executed:
                            executeMessage = "Przepis został wykonany!"
                        case .missing:
                            executeMessage = "Brakuje składników – nie można wykonać przepisu."
                        case .notAuthenticated:
                            executeMessage = "Zaloguj się, aby wykonać przepis."
                        case .error:
                            executeMessage = "Wystąpił błąd podczas wykonywania przepisu."
                        }
                    }

                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run { executeMessage = nil }
                }
            }
        } message: {
            Text("Produkty potrzebne do przepisu zostaną odjęte z Twojej spiżarni.")
        }
        
        .navigationTitle("Szczegóły przepisu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { toggleFavorite() }) {
                    Image(systemName: isFavorite ? "heart.circle.fill" : "heart.circle")
                        .font(.system(size: 24))
                        .foregroundColor(isFavorite ? .red : Color("textPrimary"))
                }
            }
        }
        .task {
            if recipe.steps.isEmpty { await loadStepsFromDB() }
            await loadIngredientsFromDB()
            await loadIngredientsAvailability()
            await loadCategoriesFromDB()
            await loadFavoriteStatus()
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

    private func loadIngredientsAvailability() async {
        do {
            let availability = try await recipeVM.ingredientsAvailability(for: recipe.id)
            await MainActor.run {
                self.ingredientAvailability = availability
            }
        } catch {
            print("[RecipeDetailView] loadIngredientsAvailability error:", error)
        }
    }

    private func loadFavoriteStatus() async {
        do {
            let userId = auth.currentUser?.id ?? ""
            guard !userId.isEmpty else {
                await MainActor.run { isFavorite = false }
                return
            }
            
            let rows: [FavoriteRow] = try await SupabaseManager.shared.client
                .from("favorite_recipe")
                .select("id")
                .eq("user_id", value: userId)
                .eq("recipe_id", value: recipe.id)
                .execute()
                .value
            
            await MainActor.run { isFavorite = !rows.isEmpty }
        } catch {
            print("loadFavoriteStatus error:", error)
        }
    }

    private struct NewFavorite: Encodable {
        let user_id: String
        let recipe_id: UUID
    }

    private func toggleFavorite() {
        Task {
            do {
                let userId = auth.currentUser?.id ?? ""
                if isFavorite {
                    try await SupabaseManager.shared.client
                        .from("favorite_recipe")
                        .delete()
                        .eq("user_id", value: userId)
                        .eq("recipe_id", value: recipe.id)
                        .execute()
                    await MainActor.run {
                        isFavorite = false
                        favoriteMessage = "Usunięto przepis z ulubionych!"
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run { favoriteMessage = nil }
                    }
                } else {
                    let payload = NewFavorite(user_id: userId, recipe_id: recipe.id)
                    try await SupabaseManager.shared.client
                        .from("favorite_recipe")
                        .insert(payload)
                        .execute()
                    await MainActor.run {
                        isFavorite = true
                        favoriteMessage = "Dodano przepis do ulubionych!"
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run { favoriteMessage = nil }
                    }
                }
            } catch {
                print("toggleFavorite error:", error)
            }
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
