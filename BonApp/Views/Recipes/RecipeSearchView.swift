import SwiftUI
import Supabase

struct RecipeSearchView: View {
    @EnvironmentObject var auth: AuthViewModel

    @StateObject private var viewModel = RecipeSearchViewModel()
    @State private var searchText: String = ""
    @State private var maxCookTime: Double = 60
    @State private var showOnlyFavorites: Bool = false
    @State private var path: [SearchRecipeItem] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                HStack {
                    Text("Max czas: \(Int(maxCookTime)) min")
                        .foregroundColor(Color("textPrimary"))
                    Spacer()
                }
                .padding(.horizontal)

                Slider(value: $maxCookTime, in: 5...180, step: 5)
                    .tint(Color("accent"))
                    .padding(.horizontal)

                Toggle("Pokaż tylko ulubione", isOn: $showOnlyFavorites)
                    .padding(.horizontal)
                    .toggleStyle(SwitchToggleStyle(tint: Color("toggleButton")))

                VStack(alignment: .leading) {
                    Text("Filtruj po kategoriach")
                        .foregroundColor(Color("textPrimary"))
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(viewModel.allCategories, id: \.self) { cat in
                                Button(action: {
                                    if viewModel.selectedCategories.contains(cat) {
                                        viewModel.selectedCategories.remove(cat)
                                    } else {
                                        viewModel.selectedCategories.insert(cat)
                                    }
                                }) {
                                    Text(cat)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(viewModel.selectedCategories.contains(cat) ? Color("addActive") : Color("itemsListBackground"))
                                        .foregroundColor(viewModel.selectedCategories.contains(cat) ? Color("textPrimary") : Color("textPrimary"))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                if let error = viewModel.error {
                    Text("Błąd: \(error)")
                        .foregroundColor(.secondary)
                }

                List {
                    ForEach(viewModel.results) { recipe in
                        NavigationLink(value: recipe) {
                            SearchResultCardView(
                                title: recipe.title,
                                cookTime: recipe.cookTime,
                                imageURL: recipe.imageURL,
                                isFavorite: viewModel.favorites.contains(recipe.id)
                            )
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
            .navigationDestination(for: SearchRecipeItem.self) { recipe in
                destination(for: recipe)
            }
            .task {
                if path.isEmpty {
                    await viewModel.search(query: searchText, maxCookTime: Int(maxCookTime), showOnlyFavorites: showOnlyFavorites, categories: viewModel.selectedCategories, currentUserId: auth.currentUser?.id)
                }
            }
            .onChange(of: searchText, initial: false) { _, _ in
                if path.isEmpty {
                    Task { await viewModel.search(query: searchText, maxCookTime: Int(maxCookTime), showOnlyFavorites: showOnlyFavorites, categories: viewModel.selectedCategories, currentUserId: auth.currentUser?.id) }
                }
            }
            .onChange(of: maxCookTime, initial: false) { _, _ in
                if path.isEmpty {
                    Task { await viewModel.search(query: searchText, maxCookTime: Int(maxCookTime), showOnlyFavorites: showOnlyFavorites, categories: viewModel.selectedCategories, currentUserId: auth.currentUser?.id) }
                }
            }
            .onChange(of: showOnlyFavorites, initial: false) { _, _ in
                if path.isEmpty {
                    Task { await viewModel.search(query: searchText, maxCookTime: Int(maxCookTime), showOnlyFavorites: showOnlyFavorites, categories: viewModel.selectedCategories, currentUserId: auth.currentUser?.id) }
                }
            }
            .onChange(of: viewModel.selectedCategories, initial: false) { _, _ in
                if path.isEmpty {
                    Task {
                        await viewModel.search(
                            query: searchText,
                            maxCookTime: Int(maxCookTime),
                            showOnlyFavorites: showOnlyFavorites,
                            categories: viewModel.selectedCategories,
                            currentUserId: auth.currentUser?.id
                        )
                    }
                }
            }
            .onChange(of: auth.currentUser?.id, initial: false) { _, _ in
                if path.isEmpty {
                    Task { await viewModel.search(query: searchText, maxCookTime: Int(maxCookTime), showOnlyFavorites: showOnlyFavorites, categories: viewModel.selectedCategories, currentUserId: auth.currentUser?.id) }
                }
            }
        }
    }

    private func destination(for recipe: SearchRecipeItem) -> some View {
        RecipeDetailView(recipe: RecipeDetailItem(
            id: recipe.id,
            title: recipe.title,
            detail: recipe.description,
            cookTime: recipe.cookTime,
            imageURL: recipe.imageURL,
            ingredients: [],
            isPublic: recipe.isPublic,
            userId: recipe.userId,
            steps: []
        ))
    }
}

private struct SearchResultCardView: View {
    let title: String
    let cookTime: Int
    let imageURL: String?
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let imageURL,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 72, height: 72)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipped()
                    case .failure:
                        Color("itemsListBackground")
                            .frame(width: 72, height: 72)
                    @unknown default:
                        Color("itemsListBackground")
                            .frame(width: 72, height: 72)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Color("itemsListBackground")
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(Color("textPrimary"))
                        .lineLimit(1)

                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("\(cookTime) min")
                }
                .font(.subheadline)
                .foregroundColor(Color("textSecondary"))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(Color("textSecondary"))
        }
        .padding(12)
        .background(Color("itemsListBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
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
