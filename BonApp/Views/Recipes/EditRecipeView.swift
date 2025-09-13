import UIKit
import SwiftUI
import Foundation
import Supabase

private struct RecipeUpdatePayload: Encodable {
    let title: String
    let detail: String
    let is_public: Bool
    let cook_time: Int
    let ingredients: [String]
    let image_url: String?
}

private struct RecipeStepInsert: Encodable {
    let id: UUID
    let recipe_id: UUID
    let order: Int
    let instruction: String
}

struct EditRecipeView: View {
    let recipeId: UUID
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var detail: String
    @State private var ingredientsText: String
    @State private var cookTime: String
    @State private var isPublic: Bool

    @State private var stepTexts: [String]
    @State private var newStepText: String = ""

    // Image handling
    @State private var selectedImage: UIImage? = nil
    @State private var currentImageURL: String? = nil
    @State private var isShowingImagePicker = false
    @State private var imageRemoved = false

    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    init(recipeId: UUID,
         title: String = "",
         detail: String = "",
         ingredients: [String] = [],
         cookTime: Int = 0,
         isPublic: Bool = false,
         steps: [String] = [],
         imageURL: String? = nil) {
        self.recipeId = recipeId
        _title = State(initialValue: title)
        _detail = State(initialValue: detail)
        _ingredientsText = State(initialValue: ingredients.joined(separator: ", "))
        _cookTime = State(initialValue: String(cookTime))
        _isPublic = State(initialValue: isPublic)
        _stepTexts = State(initialValue: steps)
        _currentImageURL = State(initialValue: imageURL)
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
                            Button("Zmień zdjęcie") { isShowingImagePicker = true }
                                .padding()
                                .frame(height: 44)
                                .background(Color("textfieldBackground"))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                                .cornerRadius(8)

                            Spacer()

                            Button(role: .destructive) {
                                selectedImage = nil
                                imageRemoved = true
                            } label: { Text("Usuń zdjęcie") }
                                .padding()
                                .frame(height: 44)
                                .background(Color("textfieldBackground"))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                                .cornerRadius(8)
                        }
                    } else if let urlString = currentImageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty: ProgressView()
                            case .success(let image): image.resizable().scaledToFit().cornerRadius(8)
                            case .failure: placeholderImage
                            @unknown default: placeholderImage
                            }
                        }
                        HStack {
                            Button("Zmień zdjęcie") { isShowingImagePicker = true }
                                .padding()
                                .frame(height: 44)
                                .background(Color("textfieldBackground"))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                                .cornerRadius(8)

                            Spacer()

                            Button(role: .destructive) {
                                currentImageURL = nil
                                imageRemoved = true
                            } label: { Text("Usuń zdjęcie") }
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
                        .padding()
                        .background(Color("addStep"))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                        .cornerRadius(8)
                    }
                }

                if let errorMessage { Text(errorMessage).foregroundColor(.red) }

                Button(isSaving ? "Zapisywanie…" : "Zapisz zmiany") {
                    Task { await saveChanges() }
                }
                .disabled(!canSave || isSaving)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(canSave && !isSaving ? Color("edit") : Color("textfieldBorder"))
                .foregroundColor(Color("buttonText"))
                .cornerRadius(8)
            }
            .padding()
        }
        .background(Color("background").ignoresSafeArea())
        .sheet(isPresented: $isShowingImagePicker) { ImagePicker(image: $selectedImage) }
        .navigationTitle("Edytuj przepis")
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(cookTime.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private var placeholderImage: some View {
        Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 180).cornerRadius(8)
    }

    private func saveChanges() async {
        guard let _ = auth.currentUser?.id else {
            await MainActor.run { errorMessage = "Brak zalogowanego użytkownika." }
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let client = SupabaseManager.shared.client
        let cookTimeInt = Int(cookTime.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let ingredientsArray = ingredientsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        do {
            // Handle image: upload new or remove
            var newImageURL: String? = currentImageURL
            if let img = selectedImage, let data = img.jpegData(compressionQuality: 0.85) {
                let path = "\(recipeId)/image.jpg"
                _ = try await client.storage
                    .from("recipes")
                    .upload(path, data: data, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true))
                newImageURL = try client.storage.from("recipes").getPublicURL(path: path).absoluteString
                imageRemoved = false
            } else if imageRemoved {
                newImageURL = nil
            }

            // 1) Update main recipe row
            let updatePayload = RecipeUpdatePayload(
                title: title,
                detail: detail,
                is_public: isPublic,
                cook_time: cookTimeInt,
                ingredients: ingredientsArray,
                image_url: newImageURL
            )

            _ = try await client
                .from("recipe")
                .update(updatePayload)
                .eq("id", value: recipeId)
                .eq("user_id", value: auth.currentUser?.id ?? "")
                .execute()

            // 2) Replace steps: delete existing, insert new
            _ = try await client
                .from("recipe_steps")
                .delete()
                .eq("recipe_id", value: recipeId)
                .execute()
            
            if !stepTexts.isEmpty {
                let stepsPayload: [RecipeStepInsert] = stepTexts.enumerated().map { (index, text) in
                    RecipeStepInsert(
                        id: UUID(),
                        recipe_id: recipeId,
                        order: index + 1,
                        instruction: text
                    )
                }
                _ = try await client
                    .from("recipe_steps")
                    .insert(stepsPayload)
                    .execute()
            }

            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

struct EditRecipeView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleId = UUID()
        return NavigationStack {
            EditRecipeView(
                recipeId: sampleId,
                title: "Przykład",
                detail: "Opis przepisu",
                ingredients: ["Składnik1", "Składnik2"],
                cookTime: 15,
                isPublic: true,
                steps: ["Krok 1", "Krok 2"],
                imageURL: nil
            )
            .environmentObject(AuthViewModel())
        }
    }
}
