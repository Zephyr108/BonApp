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
            .task {
                let uid = await auth.resolveActiveUserId()
                print("Active UID:", uid ?? "nil")
                await viewModel.refresh(currentUserId: uid)
            }
            .onChange(of: auth.currentUser?.id, initial: false) { _, _ in
                Task {
                    let uid = await auth.resolveActiveUserId()
                    print("UID changed →", uid ?? "nil")
                    await viewModel.refresh(currentUserId: uid)
                }
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
            steps: []
        ))
    }

    private func toggleFavorite(for recipeId: UUID) {
        Task {
            if let uid = auth.currentUser?.id, !uid.isEmpty {
                await viewModel.toggleFavorite(userId: uid, recipeId: recipeId)
            } else if let session = try? await SupabaseManager.shared.client.auth.session {
                await viewModel.toggleFavorite(userId: session.user.id.uuidString, recipeId: recipeId)
            }
        }
    }
}

struct RecipeListView_Previews: PreviewProvider {
    static var previews: some View {
        RecipeListView()
            .environmentObject(AuthViewModel())
    }
}
