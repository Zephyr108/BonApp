import SwiftUI
import Supabase

// DTO for search results
struct SearchRecipeItem: Identifiable, Hashable, Decodable {
    let id: UUID
    let title: String
    let detail: String?
    let cookTime: Int
    let imageURL: String?
    let isPublic: Bool
    let userId: String
    let ingredients: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, detail, ingredients
        case cookTime = "cook_time"
        case imageURL = "image_url"
        case isPublic = "is_public"
        case userId = "user_id"
    }
}

final class RecipeSearchViewModel: ObservableObject {
    @Published var results: [SearchRecipeItem] = []
    @Published var favorites: Set<UUID> = []
    @Published var isLoading = false
    @Published var error: String? = nil

    private let client = SupabaseManager.shared.client

    @MainActor
    func search(query: String, maxCookTime: Int, showOnlyFavorites: Bool, currentUserId: String?) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            var favIds: [UUID] = []
            if let uid = currentUserId {
                struct FavRow: Decodable { let recipe_id: UUID }
                let favRows: [FavRow] = try await client.database
                    .from("favorite_recipe")
                    .select("recipe_id")
                    .eq("user_id", value: uid)
                    .execute()
                    .value
                favIds = favRows.map { $0.recipe_id }
                self.favorites = Set(favIds)
            } else {
                self.favorites = []
            }

            var rq = client.database
                .from("recipe")
                .select("id,title,detail,cook_time,image_url,is_public,user_id,ingredients")

            // Apply filters first (on PostgrestFilterBuilder)
            rq = rq.lte("cook_time", value: maxCookTime)

            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                rq = rq.ilike("title", pattern: "%\(trimmed)%")
            }

            if showOnlyFavorites, !favIds.isEmpty {
                rq = rq.in("id", values: favIds)
            }

            // Apply ordering at the end and execute in one step
            let rows: [SearchRecipeItem] = try await rq.order("title", ascending: true).execute().value

            if let uid = currentUserId {
                // Only show my recipes or public ones by others
                self.results = rows.filter { $0.userId == uid || $0.isPublic }
            } else {
                self.results = rows.filter { $0.isPublic }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct RecipeSearchView: View {
    @EnvironmentObject var auth: AuthViewModel

    @StateObject private var viewModel = RecipeSearchViewModel()
    @State private var searchText: String = ""
    @State private var maxCookTime: Double = 60
    @State private var showOnlyFavorites: Bool = false

    @State private var selectedId: UUID? = nil
    @State private var isNavigating = false

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Text("Max czas: \(Int(maxCookTime)) min")
                        .foregroundColor(Color("textPrimary"))
                    Spacer()
                }
                .padding(.horizontal)

                Slider(value: $maxCookTime, in: 0...150, step: 5)
                    .tint(Color("accent"))
                    .padding(.horizontal)

                Toggle("Pokaż tylko ulubione", isOn: $showOnlyFavorites)
                    .padding(.horizontal)
                    .toggleStyle(SwitchToggleStyle(tint: Color("toggleButton")))

                if let error = viewModel.error {
                    Text("Błąd: \(error)")
                        .foregroundColor(.secondary)
                }

                List {
                    ForEach(viewModel.results) { recipe in
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
                                authorId: recipe.userId,
                                isFavorite: viewModel.favorites.contains(recipe.id)
                            ))
                            .padding(8)
                            .background(Color("itemsListBackground"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                            .onTapGesture { selectedId = recipe.id; isNavigating = true }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
            .background(Color("background").ignoresSafeArea())
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Szukaj przepisów")
            .navigationTitle("Wyszukaj")
            .task { await viewModel.search(query: searchText, maxCookTime: Int(maxCookTime), showOnlyFavorites: showOnlyFavorites, currentUserId: auth.currentUser?.id) }
            .onChange(of: searchText) { _, _ in Task { await viewModel.search(query: searchText, maxCookTime: Int(maxCookTime), showOnlyFavorites: showOnlyFavorites, currentUserId: auth.currentUser?.id) } }
            .onChange(of: maxCookTime) { _, _ in Task { await viewModel.search(query: searchText, maxCookTime: Int(maxCookTime), showOnlyFavorites: showOnlyFavorites, currentUserId: auth.currentUser?.id) } }
            .onChange(of: showOnlyFavorites) { _, _ in Task { await viewModel.search(query: searchText, maxCookTime: Int(maxCookTime), showOnlyFavorites: showOnlyFavorites, currentUserId: auth.currentUser?.id) } }
            .onChange(of: auth.currentUser?.id) { _, _ in Task { await viewModel.search(query: searchText, maxCookTime: Int(maxCookTime), showOnlyFavorites: showOnlyFavorites, currentUserId: auth.currentUser?.id) } }
        }
    }

    private func destination(for recipe: SearchRecipeItem) -> some View {
        RecipeDetailView(recipe: RecipeDetailItem(
            id: recipe.id,
            title: recipe.title,
            detail: recipe.detail,
            cookTime: recipe.cookTime,
            imageURL: recipe.imageURL,
            ingredients: recipe.ingredients,
            isPublic: recipe.isPublic,
            userId: recipe.userId,
            steps: []
        ))
    }
}

struct RecipeSearchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            RecipeSearchView()
                .environmentObject(AuthViewModel())
        }
        .background(Color("background").ignoresSafeArea())
    }
}
