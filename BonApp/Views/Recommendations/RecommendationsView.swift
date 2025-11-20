import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var viewModel = RecommendationsViewModel()

    private enum Tab: String, CaseIterable, Identifiable {
        case preferences = "Moje preferencje"
        case pantry = "Z mojej spiżarni"
        case smallShopping = "Małe zakupy"

        var id: Self { self }
    }

    @State private var selectedTab: Tab = .preferences

    var body: some View {
        NavigationStack {
            ZStack {
                Color("background").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        Picker("", selection: $selectedTab) {
                            ForEach(Tab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 8)

                        switch selectedTab {
                        case .preferences:
                            recommendationsBlock(
                                title: "Moje preferencje",
                                items: viewModel.visiblePreferences,
                                totalCount: viewModel.recommendedByPreferences.count,
                                emptyMessage: "Brak rekomendacji na podstawie Twoich preferencji.",
                                onLoadMore: viewModel.loadMorePreferences
                            )

                        case .pantry:
                            recommendationsBlock(
                                title: "Z mojej spiżarni",
                                items: viewModel.visiblePantry,
                                totalCount: viewModel.recommendedByPantry.count,
                                emptyMessage: "Brak przepisów, które możesz przygotować z aktualnej zawartości spiżarni.",
                                onLoadMore: viewModel.loadMorePantry
                            )

                        case .smallShopping:
                            recommendationsBlock(
                                title: "Małe zakupy",
                                items: viewModel.visibleSmallShopping,
                                totalCount: viewModel.recommendedSmallShopping.count,
                                emptyMessage: "Brak przepisów, do których brakuje maksymalnie 3 składników.",
                                onLoadMore: viewModel.loadMoreSmallShopping
                            )
                        }
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
        totalCount: Int,
        emptyMessage: String,
        onLoadMore: @escaping () -> Void
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
                VStack(spacing: 16) {
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
                            HStack(spacing: 12) {
                                AsyncImage(
                                    url: recommended.imageURL.flatMap { URL(string: $0) }
                                ) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    default:
                                        Color("itemsListBackground")
                                    }
                                }
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recommended.title)
                                        .font(.headline)
                                        .foregroundColor(Color("textPrimary"))

                                    HStack(spacing: 4) {
                                        Image(systemName: "clock")
                                            .font(.subheadline)
                                        Text("\(recommended.cookTime) min")
                                    }
                                    .foregroundColor(Color("textSecondary"))
                                    .font(.subheadline)

                                    if !recommended.categories.isEmpty {
                                        Text(recommended.categories.joined(separator: ", "))
                                            .font(.footnote)
                                            .foregroundColor(Color("textSecondary"))
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color("textSecondary"))
                            }
                            .padding(12)
                            .background(Color("itemsListBackground"))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    if items.count < totalCount {
                        Button(action: onLoadMore) {
                            HStack {
                                Spacer()
                                Text("Załaduj więcej")
                                    .font(.subheadline.bold())
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .background(Color("itemsListBackground"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
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
