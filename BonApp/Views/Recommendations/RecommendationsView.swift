import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var viewModel = RecommendationsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color("background").ignoresSafeArea()
                Form {
                    Section {
                        Toggle("Szybkie (≤ 30 min)", isOn: $viewModel.filterQuick)
                            .tint(Color("accent"))
                        Toggle("Wegetariańskie", isOn: $viewModel.filterVegetarian)
                            .tint(Color("accent"))
                        Stepper(value: $viewModel.maxMissingIngredients, in: 0...5) {
                            Text("Max brakujących składników: \(viewModel.maxMissingIngredients)")
                                .foregroundColor(Color("textPrimary"))
                        }
                        .tint(Color("accent"))
                    } header: {
                        Text("Filtry")
                            .foregroundColor(Color("textSecondary"))
                    }

                    Section {
                        if viewModel.isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .listRowBackground(Color.clear)
                        } else if let error = viewModel.error {
                            Text("Błąd: \(error)")
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color("itemsListBackground"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else if viewModel.recommendations.isEmpty {
                            Text("Brak rekomendacji dla obecnych filtrów i zawartości spiżarni.")
                                .foregroundColor(Color("textSecondary"))
                                .padding(8)
                                .background(Color("itemsListBackground"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            List(viewModel.recommendations, id: \.id) { item in
                                NavigationLink(destination: RecipeDetailView(recipe: RecipeDetailItem(
                                    id: item.id,
                                    title: item.title,
                                    detail: nil,
                                    cookTime: item.cookTime,
                                    imageURL: item.imageURL,
                                    ingredients: [],
                                    isPublic: true,
                                    authorId: auth.currentUser?.id ?? "",
                                    steps: []
                                ))) {
                                    RecipeRowView(recipe: item)
                                        .padding(8)
                                        .background(Color("itemsListBackground"))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    } header: {
                        Text("Rekomendacje")
                            .foregroundColor(Color("textSecondary"))
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            .navigationTitle("Rekomendacje")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Odśwież") { Task { await viewModel.fetchRecommendations(for: auth.currentUser?.id) } }
                }
            }
            .task { await viewModel.fetchRecommendations(for: auth.currentUser?.id) }
            .onChange(of: viewModel.filterQuick) { _ in Task { await viewModel.fetchRecommendations(for: auth.currentUser?.id) } }
            .onChange(of: viewModel.filterVegetarian) { _ in Task { await viewModel.fetchRecommendations(for: auth.currentUser?.id) } }
            .onChange(of: viewModel.maxMissingIngredients) { _ in Task { await viewModel.fetchRecommendations(for: auth.currentUser?.id) } }
        }
    }
}

struct RecommendationsView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color("background").ignoresSafeArea()
            RecommendationsView()
                .environmentObject(AuthViewModel())
        }
    }
}
