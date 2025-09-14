import SwiftUI
import Supabase

struct RecipeListItem: Identifiable, Hashable, Decodable {
    let id: UUID
    let title: String
    let description: String?
    let cookTime: Int
    let imageURL: String?
    let isPublic: Bool
    let authorId: String

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case cookTime = "prepare_time"
        case imageURL = "photo"
        case isPublic = "visibility"
        case authorId = "user_id"
    }
}

private struct FavoriteInsert: Encodable {
    let user_id: String
    let recipe_id: UUID
}

final class RecipeListViewModel: ObservableObject {
    @Published var myRecipes: [RecipeListItem] = []
    @Published var otherRecipes: [RecipeListItem] = []
    @Published var favorites: Set<UUID> = []
    @Published var isLoading = false
    @Published var error: String? = nil

    private let client = SupabaseManager.shared.client

    @MainActor
    func refresh(currentUserId: String?) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let rows: [RecipeListItem] = try await client
                .from("recipe")
                .select("id,title,description,prepare_time,photo,visibility,user_id")
                .order("title", ascending: true)
                .execute()
                .value

            if let uid = currentUserId {
                self.myRecipes = rows.filter { $0.authorId == uid }
                self.otherRecipes = rows.filter { $0.isPublic && $0.authorId != uid }

                // Load favorites for user
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
        }
    }

    func deleteRecipe(_ id: UUID) async {
        do {
            _ = try await client
                .from("recipe")
                .delete()
                .eq("id", value: id)
                .execute()
            // Also delete related steps (if not cascaded in DB)
            _ = try? await client
                .from("recipe_steps")
                .delete()
                .eq("recipe_id", value: id)
                .execute()
        } catch {
            _ = await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func toggleFavorite(userId: String, recipeId: UUID) async {
        if favorites.contains(recipeId) {
            // remove from favorites
            do {
                _ = try await client
                    .from("favorite_recipe")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("recipe_id", value: recipeId)
                    .execute()
                _ = await MainActor.run { self.favorites.remove(recipeId) }
            } catch {
                _ = await MainActor.run { self.error = error.localizedDescription }
            }
        } else {
            // add to favorites
            do {
                let payload = FavoriteInsert(user_id: userId, recipe_id: recipeId)
                _ = try await client
                    .from("favorite_recipe")
                    .insert(payload)
                    .execute()
                _ = await MainActor.run { self.favorites.insert(recipeId) }
            } catch {
                _ = await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
}

struct RecipeListView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var viewModel = RecipeListViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    if viewModel.isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    if let error = viewModel.error {
                        Text("Błąd: \(error)")
                            .foregroundColor(.secondary)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    Section(header: Text("Moje przepisy").foregroundColor(Color("textSecondary"))) {
                        ForEach(viewModel.myRecipes) { recipe in
                            NavigationLink(value: recipe) {
                                RecipeRowView(recipe: RecipeItem(
                                    id: recipe.id,
                                    title: recipe.title,
                                    cookTime: recipe.cookTime,
                                    imageURL: recipe.imageURL,
                                    isPublic: recipe.isPublic,
                                    authorId: recipe.authorId,
                                    isFavorite: viewModel.favorites.contains(recipe.id)
                                ))
                                .padding(8)
                                .background(Color("itemsListBackground"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .onTapGesture(count: 2) { toggleFavorite(for: recipe.id) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteRecipe(recipe.id)
                                        await viewModel.refresh(currentUserId: auth.currentUser?.id)
                                    }
                                } label: { Label("Usuń", systemImage: "trash") }
                            }
                        }
                    }

                    Section(header: Text("Przepisy użytkowników").foregroundColor(Color("textSecondary"))) {
                        ForEach(viewModel.otherRecipes) { recipe in
                            NavigationLink(value: recipe) {
                                RecipeRowView(recipe: RecipeItem(
                                    id: recipe.id,
                                    title: recipe.title,
                                    cookTime: recipe.cookTime,
                                    imageURL: recipe.imageURL,
                                    isPublic: recipe.isPublic,
                                    authorId: recipe.authorId,
                                    isFavorite: viewModel.favorites.contains(recipe.id)
                                ))
                                .padding(8)
                                .background(Color("itemsListBackground"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .onTapGesture(count: 2) { toggleFavorite(for: recipe.id) }
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
                if auth.isAuthenticated {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: AddRecipeView()) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .navigationDestination(for: RecipeListItem.self) { recipe in
                destination(for: recipe)
            }
            .task { await viewModel.refresh(currentUserId: auth.currentUser?.id) }
            .onChange(of: auth.currentUser?.id, initial: false) { _, _ in
                Task { await viewModel.refresh(currentUserId: auth.currentUser?.id) }
            }
        }
    }

    private func destination(for recipe: RecipeListItem) -> some View {
        RecipeDetailView(recipe: RecipeDetailItem(
            id: recipe.id,
            title: recipe.title,
            detail: recipe.description,
            cookTime: recipe.cookTime,
            imageURL: recipe.imageURL,
            ingredients: [],
            isPublic: recipe.isPublic,
            userId: recipe.authorId,
            steps: [] // możesz doładować w szczegółach jeśli chcesz
        ))
    }

    private func toggleFavorite(for recipeId: UUID) {
        guard let uid = auth.currentUser?.id else { return }
        Task { await viewModel.toggleFavorite(userId: uid, recipeId: recipeId) }
    }
}

struct RecipeListView_Previews: PreviewProvider {
    static var previews: some View {
        RecipeListView()
            .environmentObject(AuthViewModel())
    }
}
