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

struct RecipeDetailView: View {
    let recipe: RecipeDetailItem
    @EnvironmentObject var auth: AuthViewModel
    @State private var loadedSteps: [RecipeStepItem] = []

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

                    if let detail = recipe.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.body)
                            .foregroundColor(Color("textPrimary"))
                    }

                    Divider()

                    Text("Składniki")
                        .font(.headline)
                        .foregroundColor(Color("textSecondary"))
                    ForEach(recipe.ingredients, id: \.self) { ingredient in
                        Text("• \(ingredient)")
                            .foregroundColor(Color("textPrimary"))
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
            if recipe.steps.isEmpty {
                await loadStepsFromDB()
            }
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
