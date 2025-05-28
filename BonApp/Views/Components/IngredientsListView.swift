import SwiftUI

struct IngredientsListView: View {
    let ingredients: [String]

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
    }
}

struct IngredientsListView_Previews: PreviewProvider {
    static var previews: some View {
        IngredientsListView(
            ingredients: [
                "2 jajka",
                "200 g mąki",
                "100 ml mleka",
                "szczypta soli"
            ]
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
