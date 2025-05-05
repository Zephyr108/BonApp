import SwiftUI
import CoreData

struct RecipeListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Recipe.title, ascending: true)],
        animation: .default)
    private var recipes: FetchedResults<Recipe>
    @EnvironmentObject var auth: AuthViewModel

    /// Only show recipes that are public, or that belong to the current user.
    private var filteredRecipes: [Recipe] {
        recipes.filter { recipe in
            if let user = auth.currentUser {
                return recipe.isPublic || recipe.author == user
            }
            return recipe.isPublic
        }
    }

    /// Recipes authored by the current user.
    private var myRecipes: [Recipe] {
        guard let user = auth.currentUser else { return [] }
        return recipes.filter { $0.author == user }
    }

    /// Public recipes authored by other users.
    private var otherRecipes: [Recipe] {
        return recipes.filter { recipe in
            recipe.isPublic && recipe.author != auth.currentUser
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    Section(header: Text("Moje przepisy")) {
                        ForEach(myRecipes) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                RecipeRowView(recipe: recipe)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteRecipe(recipe)
                                } label: {
                                    Label("Usuń", systemImage: "trash")
                                }
                            }
                        }
                    }
                    Section(header: Text("Przepisy użytkowników")) {
                        ForEach(otherRecipes) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                RecipeRowView(recipe: recipe)
                            }
                        }
                    }
                }
                HStack {
                    Spacer()
                    NavigationLink(destination: RecipeSearchView()) {
                        Label("Wyszukaj przepisy", systemImage: "magnifyingglass")
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Przepisy")
            .toolbar {
                if auth.isAuthenticated, let user = auth.currentUser {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: AddRecipeView(user: user)) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
    }
    
    private func deleteRecipe(_ recipe: Recipe) {
        withAnimation {
            viewContext.delete(recipe)
            do {
                try viewContext.save()
            } catch {
                print("Failed to delete recipe: \(error.localizedDescription)")
            }
        }
    }
}

struct RecipeListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let auth = AuthViewModel(context: context)
        auth.currentUser = User(context: context)
        auth.isAuthenticated = true
        return RecipeListView()
            .environment(\.managedObjectContext, context)
            .environmentObject(auth)
    }
}
