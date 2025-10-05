//
//  AddRecipeView.swift
//  BonApp
//

import SwiftUI
import Supabase
import UIKit

private struct RecipeInsertPayload: Encodable {
    let id: UUID
    let title: String
    let description: String
    let prepare_time: Int
    let steps_list: [String]
    let visibility: Bool
    let photo: String?
    let user_id: UUID
}

struct AddRecipeView: View {
    @EnvironmentObject var auth: AuthViewModel
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

    @State private var isSaving = false
    @State private var errorMessage: String? = nil

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
                                .onTapGesture { isShowingImagePicker = true }
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
                            .cornerRadius(8)
                        }
                    }
                    .padding(.bottom, 12)

                    if let errorMessage { Text(errorMessage).foregroundColor(.red) }

                    Button(isSaving ? "Zapisywanie…" : "Zapisz przepis") {
                        Task { await saveRecipe() }
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
            .navigationTitle("Dodaj przepis")
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(cookTime.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private func saveRecipe() async {
        // Prefer ID from loaded profile, but fall back to Auth session if profile isn't loaded yet
        var userUUID: UUID?
        if let idStr = auth.currentUser?.id, let u = UUID(uuidString: idStr) {
            userUUID = u
        } else if let session = try? await SupabaseManager.shared.client.auth.session {
            userUUID = session.user.id
        }
        guard let ownerId = userUUID else {
            await MainActor.run { errorMessage = "Brak lub niepoprawne ID zalogowanego użytkownika." }
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let client = SupabaseManager.shared.client
        let recipeId = UUID()
        let cookTimeInt = Int(cookTime.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        do {
            // 1) Upload image if provided
            var imageURL: String? = nil
            if let img = selectedImage, let data = img.jpegData(compressionQuality: 0.85) {
                let path = "\(ownerId.uuidString)/recipes/\(recipeId).jpg"
                _ = try await client.storage
                    .from("recipe-images")
                    .upload(path, data: data, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true))
                // Public URL (assuming bucket is public). If not public, you can create a signed URL.
                imageURL = try client.storage.from("recipe-images").getPublicURL(path: path).absoluteString
            }

            // 2) Insert recipe (steps kept as a JSONB list)
            let recipeInsert = RecipeInsertPayload(
                id: recipeId,
                title: title,
                description: detail,
                prepare_time: cookTimeInt,
                steps_list: stepTexts,
                visibility: isPublic,
                photo: imageURL,
                user_id: ownerId
            )

            _ = try await client
                .from("recipe")
                .insert(recipeInsert)
                .execute()

            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

struct AddRecipeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AddRecipeView()
                .environmentObject(AuthViewModel())
        }
    }
}
