import UIKit
import SwiftUI
import Foundation
import CoreData

struct EditRecipeView: View {
    @ObservedObject var recipe: Recipe
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var detail: String
    @State private var ingredientsText: String
    @State private var cookTime: String
    @State private var isPublic: Bool

    @State private var stepTexts: [String]
    @State private var newStepText: String = ""

    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false

    init(recipe: Recipe) {
        self.recipe = recipe
        _title = State(initialValue: recipe.title ?? "")
        _detail = State(initialValue: recipe.detail ?? "")
        let currentIngredients = (recipe.ingredients as? [String]) ?? []
        _ingredientsText = State(initialValue: currentIngredients.joined(separator: ", "))
        _cookTime = State(initialValue: String(recipe.cookTime))
        _isPublic = State(initialValue: recipe.isPublic)
        // Initialize step texts from existing RecipeStep objects
        let steps = (recipe.steps as? Set<RecipeStep>)?
            .sorted { $0.order < $1.order } ?? []
        _stepTexts = State(initialValue: steps.map { $0.instruction ?? "" })
        if let data = recipe.images, let uiImage = UIImage(data: data) {
            _selectedImage = State(initialValue: uiImage)
        } else {
            _selectedImage = State(initialValue: nil)
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Podstawowe")) {
                TextField("Tytuł", text: $title)
                TextField("Opis", text: $detail)
                Toggle("Publiczny", isOn: $isPublic)
            }
            Section(header: Text("Zdjęcie")) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(8)
                    HStack {
                        Button("Zmień zdjęcie") {
                            isShowingImagePicker = true
                        }
                        Spacer()
                        Button(role: .destructive) {
                            selectedImage = nil
                        } label: {
                            Text("Usuń zdjęcie")
                        }
                    }
                } else {
                    Button("Dodaj zdjęcie") {
                        isShowingImagePicker = true
                    }
                }
            }
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            Section(header: Text("Składniki (oddzielone przecinkami)")) {
                TextField("Składniki", text: $ingredientsText)
            }
            Section(header: Text("Czas przygotowania (minuty)")) {
                TextField("Czas", text: $cookTime)
                    .keyboardType(.numberPad)
            }
            Section(header: Text("Kroki")) {
                // Editable list of existing steps
                ForEach(stepTexts.indices, id: \.self) { idx in
                    HStack {
                        TextField("Krok \(idx+1)", text: $stepTexts[idx])
                        Button(role: .destructive) {
                            stepTexts.remove(at: idx)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                // Input for a new step
                HStack {
                    TextField("Nowy krok", text: $newStepText)
                    Button("Dodaj krok") {
                        let text = newStepText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        stepTexts.append(text)
                        newStepText = ""
                    }
                    .disabled(newStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            Section {
                Button("Zapisz zmiany") {
                    saveChanges()
                }
            }
        }
        .navigationTitle("Edytuj przepis")
    }

    private func saveChanges() {
        recipe.title = title
        recipe.detail = detail
        let items = ingredientsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        recipe.ingredients = items as NSArray
        if let ct = Int16(cookTime) {
            recipe.cookTime = ct
        }
        recipe.isPublic = isPublic
        // Update image
        if let uiImage = selectedImage,
           let data = uiImage.jpegData(compressionQuality: 0.8) {
            recipe.images = data
        } else {
            recipe.images = nil
        }
        // Remove existing steps
        if let existing = recipe.steps as? Set<RecipeStep> {
            existing.forEach(viewContext.delete)
        }
        // Add updated steps
        for (index, instruction) in stepTexts.enumerated() {
            let step = RecipeStep(context: viewContext)
            step.instruction = instruction
            step.order = Int16(index + 1)
            step.recipe = recipe
        }
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Błąd zapisu przepisu: \(error.localizedDescription)")
        }
    }
}

struct EditRecipeView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let sample = Recipe(context: context)
        sample.title = "Przykład"
        sample.detail = "Opis przepisu"
        sample.ingredients = ["Składnik1", "Składnik2"]
        sample.cookTime = 15
        sample.isPublic = true
        return NavigationStack {
            EditRecipeView(recipe: sample)
                .environment(\.managedObjectContext, context)
        }
    }
}
