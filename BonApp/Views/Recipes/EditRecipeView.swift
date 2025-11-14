private struct PhotoNullPayload: Encodable {
    enum CodingKeys: String, CodingKey { case photo }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeNil(forKey: .photo)
    }
}
import UIKit
import SwiftUI
import Foundation
import Supabase

private struct RecipeUpdatePayload: Encodable {
    let title: String
    let description: String
    let visibility: Bool
    let prepare_time: Int
    let steps_list: [String]
    let photo: String?
}

private struct RecipeStepInsert: Encodable {
    let id: UUID
    let recipe_id: UUID
    let order: Int
    let instruction: String
}

private struct EditCategory: Identifiable, Decodable {
    let id: Int
    let name: String
}

private struct EditProductLookup: Identifiable, Decodable {
    let id: Int
    let name: String
    let unit: String?
}

private struct EditIngredientRow: Decodable {
    let product_id: Int
    let quantity: Double
}

private struct EditRecipeStepsRow: Decodable {
    let steps_list: [String]?
}

private struct EditRecipeCategoryRow: Decodable {
    let category_id: Int
}

private struct EditRecipeCategoryInsert: Encodable {
    let recipe_id: UUID
    let category_id: Int
}

private struct EditProductInRecipeInsert: Encodable {
    let recipe_id: UUID
    let product_id: Int
    let quantity: Double
}

struct EditRecipeView: View {
    let recipeId: UUID
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var detail: String
    @State private var cookTime: String
    @State private var isPublic: Bool

    @State private var stepTexts: [String]
    @State private var newStepText: String = ""

    @State private var selectedImage: UIImage? = nil
    @State private var currentImageURL: String? = nil
    @State private var isShowingImagePicker = false
    @State private var imageRemoved = false

    @State private var allCategories: [EditCategory] = []
    @State private var selectedCategoryIds: Set<Int> = []

    @State private var allProducts: [EditProductLookup] = []
    @State private var productSearch: String = ""
    @State private var selectedProduct: EditProductLookup? = nil
    @State private var ingredientQuantity: String = ""
    @State private var ingredients: [NewRecipeProduct] = []

    @State private var showCategorySheet: Bool = false

    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    init(recipeId: UUID,
         title: String = "",
         detail: String = "",
         cookTime: Int = 0,
         isPublic: Bool = false,
         steps: [String] = [],
         imageURL: String? = nil) {
        self.recipeId = recipeId
        _title = State(initialValue: title)
        _detail = State(initialValue: detail)
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
                    Text("Kategorie")
                        .font(.headline)
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        showCategorySheet = true
                    } label: {
                        HStack {
                            if selectedCategoryIds.isEmpty {
                                Text("Wybierz kategorie")
                                    .foregroundColor(Color("textSecondary"))
                            } else {
                                let names = allCategories
                                    .filter { selectedCategoryIds.contains($0.id) }
                                    .map { $0.name }
                                Text(names.joined(separator: ", "))
                                    .foregroundColor(Color("textPrimary"))
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(Color("textSecondary"))
                        }
                        .padding(16)
                        .background(Color("textfieldBackground"))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("textfieldBorder"), lineWidth: 1))
                        .cornerRadius(8)
                    }
                }

                Group {
                    Text("Składniki")
                        .font(.headline)
                        .foregroundColor(Color("textSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Szukaj produktu", text: $productSearch)
                        .padding(12)
                        .background(Color("textfieldBackground"))
                        .cornerRadius(8)

                    let query = productSearch.trimmingCharacters(in: .whitespacesAndNewlines)
                    if query.count >= 1 {
                        ForEach(allProducts.filter { $0.name.lowercased().contains(query.lowercased()) }.prefix(5)) { prod in
                            Button {
                                selectedProduct = prod
                                productSearch = ""
                            } label: {
                                HStack {
                                    Text(prod.name)
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Text(prod.unit ?? "")
                                        .foregroundColor(Color("textSecondary"))
                                }
                            }
                            .padding(8)
                        }
                    }

                    if let p = selectedProduct {
                        HStack(spacing: 12) {
                            Text(p.name)
                                .foregroundColor(Color("textPrimary"))
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            TextField("Ilość", text: $ingredientQuantity)
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                                .padding(8)
                                .background(Color("textfieldBackground"))
                                .cornerRadius(8)
                            Text(p.unit ?? "")
                                .foregroundColor(Color("textSecondary"))
                            Button("Dodaj") {
                                if let q = Double(ingredientQuantity.replacingOccurrences(of: ",", with: ".")), q > 0 {
                                    ingredients.append(NewRecipeProduct(product_id: p.id, quantity: q, unit: p.unit))
                                    selectedProduct = nil
                                    ingredientQuantity = ""
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(8)
                    }

                    if !ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(ingredients.indices, id: \.self) { idx in
                                HStack {
                                    let ing = ingredients[idx]
                                    let prod = allProducts.first(where: { $0.id == ing.product_id })
                                    let name = prod?.name ?? "#\(ing.product_id)"
                                    let unit = prod?.unit ?? ing.unit ?? ""
                                    Text("• \(name)  \(String(format: "%.2f", ing.quantity)) \(unit)")
                                        .foregroundColor(Color("textPrimary"))
                                        .lineLimit(1)
                                    Spacer()
                                    Button(role: .destructive) { ingredients.remove(at: idx) } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
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
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showCategorySheet) {
            NavigationStack {
                List {
                    ForEach(allCategories) { cat in
                        HStack {
                            Text(cat.name)
                            Spacer()
                            if selectedCategoryIds.contains(cat.id) {
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedCategoryIds.contains(cat.id) { selectedCategoryIds.remove(cat.id) }
                            else { selectedCategoryIds.insert(cat.id) }
                        }
                    }
                }
                .navigationTitle("Kategorie")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Zamknij") { showCategorySheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Gotowe") { showCategorySheet = false }
                    }
                }
            }
        }
        .task {
            await loadAllCategories()
            await loadRecipeCategories()
            await loadAllProducts()
            await loadExistingIngredients()
            await loadExistingSteps()
        }
        .navigationTitle("Edytuj przepis")
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(cookTime.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private var placeholderImage: some View {
        ZStack {
            Rectangle()
                .fill(Color("textfieldBackground"))
                .frame(height: 180)
                .cornerRadius(8)

            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundColor(Color("textSecondary"))
        }
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
        var shouldClearPhoto = false
        let cookTimeInt = Int(cookTime.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let stepsArray = stepTexts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        do {
            var newImageURL: String? = currentImageURL
            if let img = selectedImage, let data = img.jpegData(compressionQuality: 0.85) {
                let path = "\(recipeId)/image.jpg"
                _ = try await client.storage
                    .from("recipe-images")
                    .upload(path, data: data, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true))
                newImageURL = try client.storage.from("recipe-images").getPublicURL(path: path).absoluteString
                imageRemoved = false
            } else if imageRemoved {
                // użytkownik usunął zdjęcie – wyczyść URL i oznacz kolumnę do ustawienia na NULL
                newImageURL = nil
                shouldClearPhoto = true
                // opcjonalnie usuń plik ze storage
                do {
                    let path = "\(recipeId)/image.jpg"
                    _ = try? await client.storage.from("recipe-images").remove(paths: [path])
                }
            }

            let updatePayload = RecipeUpdatePayload(
                title: title,
                description: detail,
                visibility: isPublic,
                prepare_time: cookTimeInt,
                steps_list: stepsArray,
                photo: newImageURL
            )

            _ = try await client
                .from("recipe")
                .update(updatePayload)
                .eq("id", value: recipeId)
                .eq("user_id", value: auth.currentUser?.id ?? "")
                .execute()

            if shouldClearPhoto {
                let clearPayload = PhotoNullPayload()
                _ = try await client
                    .from("recipe")
                    .update(clearPayload)
                    .eq("id", value: recipeId)
                    .eq("user_id", value: auth.currentUser?.id ?? "")
                    .execute()
            }

            // Update categories for this recipe
            do {
                _ = try await client
                    .from("recipe_category")
                    .delete()
                    .eq("recipe_id", value: recipeId)
                    .execute()

                if !selectedCategoryIds.isEmpty {
                    let payload = selectedCategoryIds.map { EditRecipeCategoryInsert(recipe_id: recipeId, category_id: $0) }
                    _ = try await client
                        .from("recipe_category")
                        .insert(payload)
                        .execute()
                }
            } catch {
                print("[EditRecipeView] update categories warning:", error)
            }

            // Update ingredients for this recipe
            do {
                _ = try await client
                    .from("product_in_recipe")
                    .delete()
                    .eq("recipe_id", value: recipeId)
                    .execute()

                if !ingredients.isEmpty {
                    let payload = ingredients.map { ing in
                        EditProductInRecipeInsert(
                            recipe_id: recipeId,
                            product_id: ing.product_id,
                            quantity: ing.quantity
                        )
                    }
                    _ = try await client
                        .from("product_in_recipe")
                        .insert(payload)
                        .execute()
                }
            } catch {
                print("[EditRecipeView] update ingredients warning:", error)
            }

            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func loadAllCategories() async {
        do {
            let result: [EditCategory] = try await SupabaseManager.shared.client
                .from("category")
                .select()
                .execute()
                .value
            await MainActor.run { self.allCategories = result }
        } catch {
            print("[EditRecipeView] loadAllCategories error:", error)
        }
    }

    private func loadRecipeCategories() async {
        do {
            let result: [EditRecipeCategoryRow] = try await SupabaseManager.shared.client
                .from("recipe_category")
                .select("category_id")
                .eq("recipe_id", value: recipeId)
                .execute()
                .value
            let ids = Set(result.map { $0.category_id })
            await MainActor.run { self.selectedCategoryIds = ids }
        } catch {
            print("[EditRecipeView] loadRecipeCategories error:", error)
        }
    }

    private func loadAllProducts() async {
        do {
            let result: [EditProductLookup] = try await SupabaseManager.shared.client
                .from("product")
                .select()
                .execute()
                .value
            await MainActor.run { self.allProducts = result }
        } catch {
            print("[EditRecipeView] loadAllProducts error:", error)
        }
    }

    private func loadExistingIngredients() async {
        do {
            let result: [EditIngredientRow] = try await SupabaseManager.shared.client
                .from("product_in_recipe")
                .select("product_id, quantity")
                .eq("recipe_id", value: recipeId)
                .execute()
                .value
            let mapped = result.map { NewRecipeProduct(product_id: $0.product_id, quantity: $0.quantity, unit: nil) }
            await MainActor.run { self.ingredients = mapped }
        } catch {
            print("[EditRecipeView] loadExistingIngredients error:", error)
        }
    }

    private func loadExistingSteps() async {
        do {
            let rows: [EditRecipeStepsRow] = try await SupabaseManager.shared.client
                .from("recipe")
                .select("steps_list")
                .eq("id", value: recipeId)
                .limit(1)
                .execute()
                .value

            if let first = rows.first, let steps = first.steps_list {
                await MainActor.run {
                    self.stepTexts = steps
                }
            }
        } catch {
            print("[EditRecipeView] loadExistingSteps error:", error)
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
                cookTime: 15,
                isPublic: true,
                steps: ["Krok 1", "Krok 2"],
                imageURL: nil
            )
            .environmentObject(AuthViewModel())
        }
    }
}
