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
    @EnvironmentObject var recipeVM: RecipeViewModel
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

    @State private var allCategories: [Category] = []
    @State private var selectedCategoryIds: Set<Int> = []
    @State private var allProducts: [ProductLookup] = []
    @State private var productSearch: String = ""
    @State private var ingredientQuantity: String = ""
    @State private var selectedProduct: ProductLookup? = nil
    @State private var ingredients: [NewRecipeProduct] = []

    @State private var showCategorySheet: Bool = false

    struct Category: Identifiable, Decodable { let id: Int; let name: String }
    struct ProductLookup: Identifiable, Decodable { let id: Int; let name: String; let unit: String? }

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
                                    let names = allCategories.filter { selectedCategoryIds.contains($0.id) }.map { $0.name }
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
                    .padding(.bottom, 12)

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
                            VStack(spacing: 4) {
                                ForEach(allProducts.filter { $0.name.lowercased().contains(query.lowercased()) }.prefix(5)) { prod in
                                    Button {
                                        selectedProduct = prod
                                        productSearch = ""
                                    } label: {
                                        HStack {
                                            Text(prod.name)
                                                .foregroundColor(Color("textPrimary"))
                                            Spacer()
                                            Text(prod.unit ?? "")
                                                .foregroundColor(Color("textSecondary"))
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Color("textfieldBackground"))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
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
                                        let prodName = allProducts.first(where: { $0.id == ing.product_id })?.name ?? "#\( ing.product_id )"
                                        Text("• \(prodName)  \(String(format: "%.2f", ing.quantity)) \(ing.unit ?? "")")
                                            .foregroundColor(Color("textPrimary"))
                                            .lineLimit(1)
                                        Spacer()
                                        Button(role: .destructive) { ingredients.remove(at: idx) } label: { Image(systemName: "trash") }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.bottom, 12)

                    Group {
                        Text("Kroki")
                            .font(.headline)
                            .foregroundColor(Color("textSecondary"))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(stepTexts.indices, id: \.self) { idx in
                            HBoxStepRow(index: idx, text: $stepTexts[idx]) {
                                stepTexts.remove(at: idx)
                            }
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                newStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color("addStepInactive")
                                : Color("addStepActive")
                            )
                            .foregroundColor(.black)
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
            .sheet(isPresented: $showCategorySheet) {
                NavigationStack {
                    List {
                        ForEach(allCategories) { cat in
                            HStack {
                                Text(cat.name)
                                Spacer()
                                if selectedCategoryIds.contains(cat.id) { Image(systemName: "checkmark").foregroundColor(.blue) }
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
                        ToolbarItem(placement: .cancellationAction) { Button("Zamknij") { showCategorySheet = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("Gotowe") { showCategorySheet = false } }
                    }
                    .task { if allCategories.isEmpty { await loadCategories() } }
                }
            }
        }
        .task { await loadAllProducts() }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(cookTime.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private func saveRecipe() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let cookTimeInt = Int(cookTime.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        do {
            let imageData = selectedImage?.jpegData(compressionQuality: 0.85)
            _ = try await recipeVM.addRecipeFull(
                title: title,
                description: detail,
                steps: stepTexts,
                prepare_time: cookTimeInt,
                imageData: imageData,
                visibility: isPublic,
                categoryIds: Array(selectedCategoryIds),
                items: ingredients
            )
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func loadCategories() async {
        do {
            let result: [Category] = try await SupabaseManager.shared.client.from("category").select().execute().value
            await MainActor.run { allCategories = result }
        } catch {}
    }
    private func loadAllProducts() async {
        do {
            let result: [ProductLookup] = try await SupabaseManager.shared.client.from("product").select().execute().value
            await MainActor.run { allProducts = result }
        } catch {}
    }
}

struct AddRecipeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AddRecipeView()
                .environmentObject(AuthViewModel())
                .environmentObject(RecipeViewModel())
        }
    }
}

private struct HBoxStepRow: View {
    let index: Int
    @Binding var text: String
    var onDelete: () -> Void
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Krok \(index+1):")
                .foregroundColor(Color("textSecondary"))
            TextField("Treść kroku", text: $text)
                .textFieldStyle(.roundedBorder)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
        }
        .padding(.vertical, 4)
    }
}
