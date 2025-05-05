import SwiftUI
import CoreData

struct RecipeSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // Fetch all recipes sorted by title
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Recipe.title, ascending: true)],
        animation: .default)
    private var recipes: FetchedResults<Recipe>
    
    @State private var searchText: String = ""
    @State private var maxCookTime: Double = 60
    
    // Filtered recipes based on search text and cook time
    private var filteredRecipes: [Recipe] {
        recipes.filter { recipe in
            let matchesName = searchText.isEmpty ||
                (recipe.title?.localizedCaseInsensitiveContains(searchText) ?? false)
            let withinTime = recipe.cookTime <= Int16(maxCookTime)
            return matchesName && withinTime
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Cook time filter
                HStack {
                    Text("Max czas: \(Int(maxCookTime)) min")
                    Spacer()
                }
                .padding(.horizontal)
                
                Slider(value: $maxCookTime, in: 0...120, step: 5)
                    .padding(.horizontal)
                
                List {
                    ForEach(filteredRecipes) { recipe in
                        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                            RecipeRowView(recipe: recipe)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Szukaj przepisów")
            .navigationTitle("Wyszukaj")
        }
    }
}

struct RecipeSearchView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        // Create sample recipes for preview
        let sample1 = Recipe(context: context)
        sample1.title = "Makaron z sosem"
        sample1.cookTime = 30
        let sample2 = Recipe(context: context)
        sample2.title = "Sałatka warzywna"
        sample2.cookTime = 10
        
        return NavigationStack {
            RecipeSearchView()
                .environment(\.managedObjectContext, context)
        }
    }
}
