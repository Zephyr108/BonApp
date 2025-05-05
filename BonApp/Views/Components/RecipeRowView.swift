import SwiftUI

struct RecipeRowView: View {
    @ObservedObject var recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail image if available
            if let imageData = recipe.images, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(6)
            } else {
                // Placeholder
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title ?? "Brak tytułu")
                    .font(.headline)
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
