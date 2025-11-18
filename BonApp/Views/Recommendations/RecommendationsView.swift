import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var viewModel = RecommendationsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color("background").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        recommendationsBlock(
                            title: "Na podstawie preferencji",
                            items: viewModel.recommendedByPreferences,
                            emptyMessage: "Brak rekomendacji na podstawie preferencji."
                        )

                        recommendationsBlock(
                            title: "Na podstawie spiżarni",
                            items: viewModel.recommendedByPantry,
                            emptyMessage: "Brak rekomendacji na podstawie zawartości spiżarni."
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Rekomendacje")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Odśwież") {
                        Task {
                            await loadRecommendations()
                        }
                    }
                }
            }
            .task {
                await loadRecommendations()
            }
        }
    }

    private func loadRecommendations() async {
        if let idString = auth.currentUser?.id,
           let userUUID = UUID(uuidString: idString) {
            await viewModel.fetchRecommendations(for: userUUID)
        } else {
            await viewModel.fetchRecommendations(for: nil)
        }
    }

    // MARK: - Blok z rekomendacjami

    @ViewBuilder
    private func recommendationsBlock(
        title: String,
        items: [RecommendationsViewModel.RecommendedRecipe],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color("textSecondary"))

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let error = viewModel.error {
                Text("Błąd: \(error)")
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color("itemsListBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if items.isEmpty {
                Text(emptyMessage)
                    .foregroundColor(Color("textSecondary"))
                    .padding(8)
                    .background(Color("itemsListBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 12) {
                    ForEach(items) { recommended in
                        NavigationLink {
                            RecipeDetailView(
                                recipe: RecipeDetailItem(
                                    id: recommended.id,
                                    title: recommended.title,
                                    detail: "",
                                    cookTime: recommended.cookTime,
                                    imageURL: recommended.imageURL,
                                    ingredients: [],
                                    isPublic: recommended.isPublic,
                                    userId: recommended.authorId,
                                    steps: []
                                )
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recommended.title)
                                    .font(.headline)
                                    .foregroundColor(Color("textPrimary"))
                                Text("Czas: \(recommended.cookTime) min")
                                    .font(.subheadline)
                                    .foregroundColor(Color("textSecondary"))
                                if !recommended.categories.isEmpty {
                                    Text(recommended.categories.joined(separator: ", "))
                                        .font(.footnote)
                                        .foregroundColor(Color("textSecondary"))
                                }
                            }
                            .padding(12)
                            .background(Color("itemsListBackground"))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
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
