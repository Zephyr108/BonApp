import SwiftUI
import CoreData

struct RecipeRowView: View {
    @ObservedObject var recipe: Recipe
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: User.entity(),
        sortDescriptors: [],
        predicate: NSPredicate(format: "isCurrent == YES"),
        animation: .default
    ) private var users: FetchedResults<User>

    var body: some View {
        HStack(spacing: 12) {
            if let imageData = recipe.images, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recipe.title ?? "Brak tytułu")
                        .font(.headline)
                    if let currentUser = users.first,
                       let favorites = currentUser.favoriteRecipes as? Set<Recipe>,
                       favorites.contains(recipe) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                    }
                }
                HStack {
                    Image(systemName: "clock")
                        .font(.subheadline)
                    Text("\(recipe.cookTime) min")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    guard let currentUser = users.first else { return }
                    guard let favorites = currentUser.favoriteRecipes as? Set<Recipe> else { return }

                    var updatedFavorites = favorites
                    if updatedFavorites.contains(recipe) {
                        updatedFavorites.remove(recipe)
                    } else {
                        updatedFavorites.insert(recipe)
                    }

                    currentUser.favoriteRecipes = NSSet(set: updatedFavorites)
                    do {
                        try viewContext.save()
                    } catch {
                        print("Failed to update favorites: \(error.localizedDescription)")
                    }
                }
        )
    }
}

struct RecipeRowView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let sample = Recipe(context: context)
        sample.title = "Przykładowy przepis"
        sample.cookTime = 20
        // sample.images left nil for placeholder
        return RecipeRowView(recipe: sample)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
