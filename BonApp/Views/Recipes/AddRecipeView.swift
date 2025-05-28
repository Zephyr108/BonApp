//
//  AddRecipeView.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//

import SwiftUI
import CoreData

struct AddRecipeView: View {
    @ObservedObject var user: User
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var detail: String = ""
    @State private var ingredientsText: String = ""
    @State private var cookTime: String = ""
    @State private var isPublic: Bool = false
    @State private var selectedImage: UIImage? = nil
    @State private var isShowingImagePicker = false

    @State private var newStepText: String = ""
    @State private var stepTexts: [String] = []

    var body: some View {
        NavigationStack {
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
                            .background(Color("textfieldBackground"))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                            .cornerRadius(8)

                        TextField("Opis", text: $detail)
                            .foregroundColor(Color("textPrimary"))
                            .padding(16)
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
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                        .cornerRadius(8)
                    }
                    .padding(.bottom, 12)

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
                                .onTapGesture {
                                    isShowingImagePicker = true
                                }
                        } else {
                            Button(action: { isShowingImagePicker = true }) {
                                HStack {
                                    Label("Wybierz zdjęcie", systemImage: "photo")
                                    Spacer()
                                }
                                .padding(16)
                                .foregroundColor(.blue)
                                .background(Color("textfieldBackground"))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.bottom, 12)

                    Group {
                        Text("Składniki (oddzielone przecinkami)")
                            .font(.headline)
                            .foregroundColor(Color("textSecondary"))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        TextField("Składniki", text: $ingredientsText)
                            .foregroundColor(Color("textPrimary"))
                            .padding(16)
                            .background(Color("textfieldBackground"))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                            .cornerRadius(8)
                    }
                    .padding(.bottom, 12)

                    Group {
                        Text("Czas przygotowania (minuty)")
                            .font(.headline)
                            .foregroundColor(Color("textSecondary"))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        TextField("Czas", text: $cookTime)
                            .keyboardType(.numberPad)
                            .foregroundColor(Color("textPrimary"))
                            .padding(16)
                            .background(Color("textfieldBackground"))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                            .cornerRadius(8)
                    }
                    .padding(.bottom, 12)

                    Group {
                        Text("Kroki")
                            .font(.headline)
                            .foregroundColor(Color("textSecondary"))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(stepTexts.indices, id: \.self) { idx in
                            Text("Krok \(idx+1): \(stepTexts[idx])")
                                .foregroundColor(Color("textPrimary"))
                        }

                        HStack {
                            TextField("Nowy krok", text: $newStepText)
                                .foregroundColor(Color("textPrimary"))
                                .padding(16)
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
                            .padding(16)
                            .background(Color("addStep"))
                            //.foregroundColor(Color("textPrimary"))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.bottom, 12)

                    Button("Zapisz przepis") {
                        saveRecipe()
                    }
                    .disabled(title.isEmpty || ingredientsText.isEmpty || Int(cookTime) == nil)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color("edit"))
                    .foregroundColor(Color("buttonText"))
                    .cornerRadius(8)
                }
                .padding()
            }
            .background(Color("background").ignoresSafeArea())
            .navigationTitle("Dodaj przepis")
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }

    private func saveRecipe() {
        let newRecipe = Recipe(context: viewContext)
        newRecipe.title = title
        newRecipe.detail = detail
        let items = ingredientsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        newRecipe.ingredients = items as NSArray
        if let ct = Int16(cookTime) {
            newRecipe.cookTime = ct
        }
        newRecipe.isPublic = isPublic
        if let uiImage = selectedImage,
           let data = uiImage.jpegData(compressionQuality: 0.8) {
            newRecipe.images = data
        }
        newRecipe.author = user

        for (index, instruction) in stepTexts.enumerated() {
            let step = RecipeStep(context: viewContext)
            step.instruction = instruction
            step.order = Int16(index + 1)
            step.recipe = newRecipe
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Błąd zapisu nowego przepisu: \(error.localizedDescription)")
        }
    }
}

struct AddRecipeView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let sampleUser = User(context: context)
        sampleUser.name = "Jan"
        return NavigationStack {
            AddRecipeView(user: sampleUser)
                .environment(\.managedObjectContext, context)
        }
    }
}
