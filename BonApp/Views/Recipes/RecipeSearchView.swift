import SwiftUI
import CoreData

struct RecipeSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var auth: AuthViewModel
    
    // Fetch all recipes sorted by title
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Recipe.title, ascending: true)],
        animation: .default)
    private var recipes: FetchedResults<Recipe>
    
    @State private var searchText: String = ""
    @State private var maxCookTime: Double = 60
    @State private var showOnlyFavorites: Bool = false
    
    // Filtered recipes based on search text and cook time
    private var filteredRecipes: [Recipe] {
        recipes.filter { recipe in
            let matchesName = searchText.isEmpty ||
                (recipe.title?.localizedCaseInsensitiveContains(searchText) ?? false)
            let withinTime = recipe.cookTime <= Int16(maxCookTime)
            let isVisible = recipe.isPublic || recipe.author == auth.currentUser
            let isFavorite = !showOnlyFavorites || (auth.currentUser?.favoriteRecipes?.contains(recipe) ?? false)
            return matchesName && withinTime && isVisible && isFavorite
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Cook time filter
                HStack {
                    Text("Max czas: \(Int(maxCookTime)) min")
                        .foregroundColor(Color("textPrimary"))
                    Spacer()
                }
                .padding(.horizontal)
                
                Slider(value: $maxCookTime, in: 0...120, step: 5)
                    .tint(Color("accent"))
                    .padding(.horizontal)
                
                Toggle("Pokaż tylko ulubione", isOn: $showOnlyFavorites)
                    .padding(.horizontal)
                    .toggleStyle(SwitchToggleStyle(tint: Color("toggleButton")))
                
                List {
                    ForEach(filteredRecipes) { recipe in
                        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                            RecipeRowView(recipe: recipe)
                                .padding(8)
                                .background(Color("itemsListBackground"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
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
        
        let auth = AuthViewModel()
        
        return ZStack {
            Color("background").ignoresSafeArea()
            NavigationStack {
                RecipeSearchView()
                    .environment(\.managedObjectContext, context)
                    .environmentObject(auth)
            }
        }
    }
}
