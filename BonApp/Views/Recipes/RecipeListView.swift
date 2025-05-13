import SwiftUI
import CoreData

struct RecipeListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Recipe.title, ascending: true)],
        animation: .default)
    private var recipes: FetchedResults<Recipe>
    @EnvironmentObject var auth: AuthViewModel

    @State private var selectedRecipe: Recipe?

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
                    Section(header: Text("Moje przepisy")
                        .foregroundColor(Color("textSecondary"))) {
                        ForEach(myRecipes) { recipe in
                            ZStack {
                                NavigationLink(value: recipe) {
                                    EmptyView()
                                }
                                .frame(width: 0, height: 0)
                                .hidden()
                                
                                RecipeRowView(recipe: recipe)
                                    .padding(8)
                                    .background(Color("itemsListBackground"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedRecipe = recipe
                                    }
                                    .onTapGesture(count: 2) {
                                        toggleFavorite(for: recipe)
                                    }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteRecipe(recipe)
                                } label: {
                                    Label("Usuń", systemImage: "trash")
                                }
                            }
                        }
                    }
                    Section(header: Text("Przepisy użytkowników")
                        .foregroundColor(Color("textSecondary"))) {
                        ForEach(otherRecipes) { recipe in
                            ZStack {
                                NavigationLink(value: recipe) {
                                    EmptyView()
                                }
                                .frame(width: 0, height: 0)
                                .hidden()
                                
                                RecipeRowView(recipe: recipe)
                                    .padding(8)
                                    .background(Color("itemsListBackground"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedRecipe = recipe
                                    }
                                    .onTapGesture(count: 2) {
                                        toggleFavorite(for: recipe)
                                    }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(PlainListStyle())
                .background(Color("background"))
                HStack {
                    Spacer()
                    NavigationLink(destination: RecipeSearchView()) {
                        Label("Wyszukaj przepisy", systemImage: "magnifyingglass")
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(Color("background"))
            }
            .background(Color("background").ignoresSafeArea())
            .navigationTitle("Przepisy")
                .foregroundColor(Color("textPrimary"))
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
        .navigationDestination(for: Recipe.self) { recipe in
            RecipeDetailView(recipe: recipe)
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
    
    private func toggleFavorite(for recipe: Recipe) {
        withAnimation {
            guard let user = auth.currentUser else { return }

            if let favorites = user.favoriteRecipes as? Set<Recipe> {
                if favorites.contains(recipe) {
                    user.removeFromFavoriteRecipes(recipe)
                } else {
                    user.addToFavoriteRecipes(recipe)
                }

                do {
                    try viewContext.save()
                } catch {
                    print("Failed to toggle favorite: \(error.localizedDescription)")
                }
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

        let sampleRecipe = Recipe(context: context)
        sampleRecipe.title = "Domowy makaron"
        sampleRecipe.detail = "Prosty przepis na domowy makaron"
        sampleRecipe.cookTime = 20
        sampleRecipe.isPublic = true
        sampleRecipe.author = auth.currentUser

        return RecipeListView()
            .environment(\.managedObjectContext, context)
            .environmentObject(auth)
    }
}
