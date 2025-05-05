//
//  RecipeDetailView.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//


import SwiftUI
import UIKit

struct RecipeDetailView: View {
    @ObservedObject var recipe: Recipe
    @EnvironmentObject var auth: AuthViewModel

    private var ingredientsArray: [String] {
        (recipe.ingredients as? [String]) ?? []
    }

    /// Steps of the recipe, sorted by order.
    private var stepsArray: [RecipeStep] {
        let set = (recipe.steps as? Set<RecipeStep>) ?? []
        return set.sorted { $0.order < $1.order }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Display recipe image if available
                if let imageData = recipe.images, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(8)
                }
                
                // Title and cook time
                Text(recipe.title ?? "Brak tytułu")
                    .font(.title)
                    .bold()
                Text("Czas przygotowania: \(recipe.cookTime) min")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Description
                if let detail = recipe.detail {
                    Text(detail)
                        .font(.body)
                }
                
                Divider()
                
                // Ingredients list
                Text("Składniki")
                    .font(.headline)
                ForEach(ingredientsArray, id: \.self) { ingredient in
                    Text("• \(ingredient)")
                }

                Divider()

                // Steps list
                Text("Kroki")
                    .font(.headline)
                ForEach(stepsArray, id: \.self) { step in
                    Text("Krok \(step.order): \(step.instruction ?? "")")
                }
            }
            .padding()
        }
        .navigationTitle("Szczegóły przepisu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let user = auth.currentUser, recipe.author == user {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: EditRecipeView(recipe: recipe)) {
                        Text("Edytuj")
                    }
                }
            }
        }
    }
}

struct RecipeDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        // Mock recipe for preview
        let sample = Recipe(context: context)
        sample.title = "Przykładowy przepis"
        sample.cookTime = 25
        sample.detail = "Opis przygotowania krok po kroku."
        sample.ingredients = ["1 jajko", "200g mąki", "100ml mleka"]
        sample.isPublic = true
        return NavigationStack {
            RecipeDetailView(recipe: sample)
                .environment(\.managedObjectContext, context)
        }
    }
}
