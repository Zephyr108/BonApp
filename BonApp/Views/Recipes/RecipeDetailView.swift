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

    private var stepsArray: [RecipeStep] {
        let set = (recipe.steps as? Set<RecipeStep>) ?? []
        return set.sorted { $0.order < $1.order }
    }

    var body: some View {
        ZStack {
            Color("background").ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let imageData = recipe.images, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(8)
                    }
                    
                    Text(recipe.title ?? "Brak tytułu")
                        .font(.title)
                        .bold()
                        .foregroundColor(Color("textPrimary"))
                    Text("Czas przygotowania: \(recipe.cookTime) min")
                        .font(.subheadline)
                        .foregroundColor(Color("textSecondary"))
                    
                    if let detail = recipe.detail {
                        Text(detail)
                            .font(.body)
                            .foregroundColor(Color("textPrimary"))
                    }
                    
                    Divider()
                    
                    Text("Składniki")
                        .font(.headline)
                        .foregroundColor(Color("textSecondary"))
                    ForEach(ingredientsArray, id: \.self) { ingredient in
                        Text("• \(ingredient)")
                            .foregroundColor(Color("textPrimary"))
                    }

                    Divider()

                    Text("Kroki")
                        .font(.headline)
                        .foregroundColor(Color("textSecondary"))
                    ForEach(stepsArray, id: \.self) { step in
                        Text("Krok \(step.order): \(step.instruction ?? "")")
                            .foregroundColor(Color("textPrimary"))
                    }
                }
                .padding()
            }
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
        let sample = Recipe(context: context)
        sample.title = "Przykładowy przepis"
        sample.cookTime = 25
        sample.detail = "Opis przygotowania krok po kroku."
        sample.ingredients = ["1 jajko", "200g mąki", "100ml mleka"]
        sample.isPublic = true
        return NavigationStack {
            RecipeDetailView(recipe: sample)
                .environment(\.managedObjectContext, context)
                .environmentObject(AuthViewModel())
        }
    }
}
