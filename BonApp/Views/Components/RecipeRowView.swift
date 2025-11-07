import SwiftUI

struct RecipeItem: Identifiable, Decodable {
    let id: UUID
    let title: String
    let cookTime: Int
    let imageURL: String?
    let isPublic: Bool
    let authorId: String
    let isFavorite: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title
        case cookTime = "cook_time"
        case imageURL = "image_url"
        case isPublic = "is_public"
        case authorId = "user_id"
        case isFavorite = "is_favorite"
    }
}

struct RecipeRowView: View {
    let recipe: RecipeItem

    var body: some View {
        HStack(spacing: 12) {
            if let imageURLString = recipe.imageURL, let url = URL(string: imageURLString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 60, height: 60)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(6)
                    case .failure:
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .cornerRadius(6)
                    @unknown default:
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .cornerRadius(6)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recipe.title.isEmpty ? "Brak tytułu" : recipe.title)
                        .font(.headline)
                    if recipe.isFavorite == true {
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
                    toggleFavorite()
                }
        )
    }
    
    private func toggleFavorite() {
    }
}

struct RecipeRowView_Previews: PreviewProvider {
    static var previews: some View {
        let sample = RecipeItem(
            id: UUID(),
            title: "Przykładowy przepis",
            cookTime: 20,
            imageURL: nil,
            isPublic: true,
            authorId: "user123",
            isFavorite: true
        )
        RecipeRowView(recipe: sample)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
