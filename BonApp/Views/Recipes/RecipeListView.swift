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

private enum RecipeListTab {
    case others
    case mine
}

private struct CircleActionButton: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color("itemsListBackground"))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(Color("textPrimary"))
            }
            Text(title)
                .font(.caption2)
                .foregroundColor(Color("textSecondary"))
        }
    }
}

struct RecipeListView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var viewModel = RecipeListViewModel()
    @State private var selectedTab: RecipeListTab = .others

    private var effectiveTab: RecipeListTab {
        auth.isAuthenticated ? selectedTab : .others
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    NavigationLink {
                        RecipeSearchView()
                    } label: {
                        CircleActionButton(icon: "magnifyingglass", title: "Szukaj")
                    }

                    if auth.isAuthenticated {
                        NavigationLink {
                            RecommendationsView()
                        } label: {
                            CircleActionButton(icon: "sparkles", title: "Dla Ciebie")
                        }
                    }

                    if auth.isAuthenticated {
                        NavigationLink {
                            AddRecipeView()
                        } label: {
                            CircleActionButton(icon: "plus", title: "Dodaj")
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                HStack(spacing: 8) {
                    Button {
                        selectedTab = .others
                    } label: {
                        Text("Przepisy użytkowników")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(effectiveTab == .others ? Color("itemsListBackground") : Color.clear)
                            )
                            .foregroundColor(Color("textPrimary"))
                    }

                    if auth.isAuthenticated {
                        Button {
                            selectedTab = .mine
                        } label: {
                            Text("Moje przepisy")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(effectiveTab == .mine ? Color("itemsListBackground") : Color.clear)
                                )
                                .foregroundColor(Color("textPrimary"))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

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

                    switch effectiveTab {
                    case .others:
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
                        }

                    case .mine:
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
                }
                .scrollContentBackground(.hidden)
                .listStyle(PlainListStyle())
                .background(Color("background"))
            }
            .background(Color("background").ignoresSafeArea())
            .navigationTitle("Przepisy")
            .foregroundColor(Color("textPrimary"))
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
            .onChange(of: auth.isAuthenticated, initial: false) { _, isAuthenticated in
                if !isAuthenticated {
                    selectedTab = .others
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
