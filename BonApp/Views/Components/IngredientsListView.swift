import SwiftUI
import Supabase

struct IngredientsListView: View {
    @State private var ingredients: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Składniki")
                .font(.headline)
            ForEach(ingredients, id: \.self) { ingredient in
                Text("• \(ingredient)")
                    .font(.body)
            }
        }
        .padding(.vertical, 8)
        .task { await loadIngredients() }
    }

    private func loadIngredients() async {
        do {
            let client = SupabaseManager.shared.client
            let rows: [ProductRow] = try await client.database
                .from("products")
                .select("name")
                .execute()
                .value
            self.ingredients = rows.compactMap { $0.name }
        } catch {
            print("Failed to load ingredients: \(error.localizedDescription)")
        }
    }
}

private struct ProductRow: Decodable {
    let name: String?
}

struct IngredientsListView_Previews: PreviewProvider {
    static var previews: some View {
        IngredientsListView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
