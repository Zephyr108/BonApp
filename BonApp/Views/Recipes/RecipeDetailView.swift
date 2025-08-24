//
//  RecipeDetailView.swift
//  BonApp
//
//  Migrated to Supabase (no Core Data)
//

import SwiftUI
import UIKit

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
    let authorId: String
    let steps: [RecipeStepItem]
}

struct RecipeDetailView: View {
    let recipe: RecipeDetailItem
    @EnvironmentObject var auth: AuthViewModel

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
                    ForEach(recipe.steps.sorted { $0.order < $1.order }) { step in
                        Text("Krok \(step.order): \(step.instruction)")
                            .foregroundColor(Color("textPrimary"))
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Szczegóły przepisu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let user = auth.currentUser, user.id == recipe.authorId {
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
            authorId: "00000000-0000-0000-0000-000000000000",
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
