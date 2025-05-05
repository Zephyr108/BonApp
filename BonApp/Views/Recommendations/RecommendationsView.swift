import SwiftUI

struct RecommendationsView: View {
    @ObservedObject var user: User
    @StateObject private var viewModel = RecommendationsViewModel()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Filtry") {
                    Toggle("Szybkie (≤ 30 min)", isOn: $viewModel.filterQuick)
                    Toggle("Wegetariańskie", isOn: $viewModel.filterVegetarian)
                    Toggle("Budżetowe", isOn: $viewModel.filterBudget)
                    Stepper(value: $viewModel.maxMissingIngredients, in: 0...5) {
                        Text("Max brakujących składników: \(viewModel.maxMissingIngredients)")
                    }
                }
                
                Section("Rekomendacje") {
                    if viewModel.recommendations.isEmpty {
                        Text("Brak rekomendacji dla obecnych filtrów i zawartości spiżarni.")
                            .foregroundColor(.secondary)
                    } else {
                        List(viewModel.recommendations, id: \.self) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                RecipeRowView(recipe: recipe)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Rekomendacje")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Odśwież") {
                        viewModel.fetchRecommendations(for: user)
                    }
                }
            }
            .onAppear {
                viewModel.fetchRecommendations(for: user)
            }
        }
    }
}

struct RecommendationsView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        // Create a sample user with pantry items for preview
        let user = User(context: context)
        user.name = "Jan"
        let samplePantry = PantryItem(context: context)
        samplePantry.name = "Mąka"
        samplePantry.quantity = "1 kg"
        samplePantry.category = "Pieczywo"
        samplePantry.owner = user
        return RecommendationsView(user: user)
            .environment(\.managedObjectContext, context)
    }
}
