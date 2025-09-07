import SwiftUI
import Supabase

// Minimal DTO for list rows
struct RecipeListItem: Identifiable, Hashable, Decodable {
    let id: UUID
    let title: String
    let detail: String?
    let cookTime: Int
    let imageURL: String?
    let isPublic: Bool
    let authorId: String
    let ingredients: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, detail, ingredients
        case cookTime = "cook_time"
        case imageURL = "image_url"
        case isPublic = "is_public"
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
            let rows: [RecipeListItem] = try await client.database
                .from("recipe")
                .select("id,title,detail,cook_time,image_url,is_public,user_id,ingredients")
                .order("title", ascending: true)
                .execute()
                .value

            if let uid = currentUserId {
                self.myRecipes = rows.filter { $0.authorId == uid }
                self.otherRecipes = rows.filter { $0.isPublic && $0.authorId != uid }

                // Load favorites for user
                struct FavRow: Decodable { let recipe_id: UUID }
                let favRows: [FavRow] = try await client.database
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
            _ = try await client.database
                .from("recipe")
                .delete()
                .eq("id", value: id)
                .execute()
            // Also delete related steps (if not cascaded in DB)
            _ = try? await client.database
                .from("recipe_steps")
                .delete()
                .eq("recipe_id", value: id)
                .execute()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func toggleFavorite(userId: String, recipeId: UUID) async {
        if favorites.contains(recipeId) {
            // remove
            do {
                _ = try await client.database
                    .from("favorite_recipe")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("recipe_id", value: recipeId)
                    .execute()
                await MainActor.run { self.favorites.remove(recipeId) }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        } else {
            // add
            do {
                let payload = FavoriteInsert(user_id: userId, recipe_id: recipeId)
                _ = try await client.database
                    .from("favorite_recipe")
                    .insert(payload)
                    .execute()
                await MainActor.run { self.favorites.insert(recipeId) }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
}

struct RecipeListView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var viewModel = RecipeListViewModel()

    @State private var selectedId: UUID? = nil
    @State private var isNavigating = false

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
                            ZStack {
                                NavigationLink(
                                    destination: destination(for: recipe),
                                    isActive: Binding(
                                        get: { selectedId == recipe.id && isNavigating },
                                        set: { newValue in if !newValue { selectedId = nil; isNavigating = false } }
                                    )
                                ) { EmptyView() }.opacity(0)

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
                                .onTapGesture { selectedId = recipe.id; isNavigating = true }
                                .onTapGesture(count: 2) { toggleFavorite(for: recipe.id) }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
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
                            ZStack {
                                NavigationLink(
                                    destination: destination(for: recipe),
                                    isActive: Binding(
                                        get: { selectedId == recipe.id && isNavigating },
                                        set: { newValue in if !newValue { selectedId = nil; isNavigating = false } }
                                    )
                                ) { EmptyView() }.opacity(0)

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
                                .onTapGesture { selectedId = recipe.id; isNavigating = true }
                                .onTapGesture(count: 2) { toggleFavorite(for: recipe.id) }
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
                if auth.isAuthenticated {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: AddRecipeView()) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .task { await viewModel.refresh(currentUserId: auth.currentUser?.id) }
            .onChange(of: auth.currentUser?.id) { _, _ in
                Task { await viewModel.refresh(currentUserId: auth.currentUser?.id) }
            }
        }
    }

    private func destination(for recipe: RecipeListItem) -> some View {
        RecipeDetailView(recipe: RecipeDetailItem(
            id: recipe.id,
            title: recipe.title,
            detail: recipe.detail,
            cookTime: recipe.cookTime,
            imageURL: recipe.imageURL,
            ingredients: recipe.ingredients,
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
