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
        ScrollView {
            VStack(spacing: 16) {
                Group {
                    Text("Podstawowe")
                        .font(.headline)
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Tytuł", text: $title)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        //.frame(height: 44)
                        .background(Color("textfieldBackground"))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                        .cornerRadius(8)

                    TextField("Opis", text: $detail)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        //.frame(height: 44)
                        .background(Color("textfieldBackground"))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                        .cornerRadius(8)

                    HStack {
                        Text("Publiczny")
                            .foregroundColor(Color("textPrimary"))
                        Spacer()
                        Toggle("", isOn: $isPublic)
                            .labelsHidden()
                    }
                    .padding(12)
                    .background(Color("textfieldBackground"))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                    .cornerRadius(8)
                }

                Group {
                    Text("Zdjęcie")
                        .font(.headline)
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(8)

                        HStack {
                            Button("Zmień zdjęcie") {
                                isShowingImagePicker = true
                            }
                            .padding()
                            .frame(height: 44)
                            .background(Color("textfieldBackground"))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                            .cornerRadius(8)

                            Spacer()

                            Button(role: .destructive) {
                                selectedImage = nil
                            } label: {
                                Text("Usuń zdjęcie")
                            }
                            .padding()
                            .frame(height: 44)
                            .background(Color("textfieldBackground"))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                            .cornerRadius(8)
                        }
                    } else {
                        Button(action: { isShowingImagePicker = true }) {
                            HStack {
                                Label("Dodaj zdjęcie", systemImage: "photo")
                                Spacer()
                            }
                        }
                        .padding()
                        //.frame(height: 44)
                        .foregroundColor(.blue)
                        .background(Color("textfieldBackground"))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                        .cornerRadius(8)
                    }
                }

                Group {
                    Text("Składniki (oddzielone przecinkami)")
                        .font(.headline)
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Składniki", text: $ingredientsText)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        //.frame(height: 44)
                        .background(Color("textfieldBackground"))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                        .cornerRadius(8)
                }

                Group {
                    Text("Czas przygotowania (minuty)")
                        .font(.headline)
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Czas", text: $cookTime)
                        .keyboardType(.numberPad)
                        .foregroundColor(Color("textPrimary"))
                        .padding(16)
                        //.frame(height: 44)
                        .background(Color("textfieldBackground"))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                        .cornerRadius(8)
                }

                Group {
                    Text("Kroki")
                        .font(.headline)
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(stepTexts.indices, id: \.self) { idx in
                        HStack {
                            TextField("Krok \(idx+1)", text: $stepTexts[idx])
                                .padding()
                                .frame(height: 44)
                                .background(Color("textfieldBackground"))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                                .cornerRadius(8)

                            Button(role: .destructive) {
                                stepTexts.remove(at: idx)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .padding()
                            .frame(height: 44)
                            .background(Color("textfieldBackground"))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                            .cornerRadius(8)
                        }
                    }

                    HStack {
                        TextField("Nowy krok", text: $newStepText)
                            .padding()
                            .background(Color("textfieldBackground"))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                            .cornerRadius(8)

                        Button("Dodaj krok") {
                            let text = newStepText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !text.isEmpty else { return }
                            stepTexts.append(text)
                            newStepText = ""
                        }
                        .disabled(newStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        //.foregroundColor(Color("textPrimary"))
                        .padding()
                        .background(Color("addStep"))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                        .cornerRadius(8)
                    }
                }

                Button("Zapisz zmiany") {
                    saveChanges()
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color("edit"))
                .foregroundColor(Color("buttonText"))
                .cornerRadius(8)
            }
            .padding()
        }
        .background(Color("background").ignoresSafeArea())
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $selectedImage)
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
        // Update zdj
        if let uiImage = selectedImage,
           let data = uiImage.jpegData(compressionQuality: 0.8) {
            recipe.images = data
        } else {
            recipe.images = nil
        }
        if let existing = recipe.steps as? Set<RecipeStep> {
            existing.forEach(viewContext.delete)
        }
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
