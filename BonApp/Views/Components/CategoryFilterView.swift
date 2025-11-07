//
//  CategoryFilterView.swift
//  BonApp
//
//  Migrated to Supabase – dynamic categories
//

import SwiftUI

struct CategoryFilterView: View {
    @Binding var selectedCategory: String?

    @State private var categories: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private let includeAllChip = true
    private let allLabel = "Wszystkie"

    var body: some View {
        VStack(spacing: 8) {
            if isLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { ProgressView().padding(.horizontal) }
                }
            } else if let errorMessage {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(displayedCategories, id: \.self) { category in
                            Button(action: {
                                if selectedCategory == normalized(category) || (includeAllChip && category == allLabel) {
                                    selectedCategory = nil
                                } else {
                                    selectedCategory = normalized(category)
                                }
                            }) {
                                Text(category)
                                    .font(.subheadline)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isSelected(category) ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                                    )
                            }
                            .foregroundColor(isSelected(category) ? .accentColor : .primary)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task { await loadCategories() }
    }

    private var displayedCategories: [String] {
        var list = categories
        if includeAllChip {
            list.insert(allLabel, at: 0)
        }
        return list
    }

    private func isSelected(_ label: String) -> Bool {
        if includeAllChip && label == allLabel { return selectedCategory == nil }
        return selectedCategory == normalized(label)
    }

    private func normalized(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: - Data loading from Supabase
    private func loadCategories() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let names1: [String] = try await fetchCategoryNamesFromCategoryTable()
            if !names1.isEmpty {
                categories = uniqueSorted(names1)
                return
            }

            let names2: [String] = try await fetchCategoryNamesFromProductsJoin()
            categories = uniqueSorted(names2)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uniqueSorted(_ array: [String]) -> [String] {
        Array(Set(array.map { normalized($0) })).filter { !$0.isEmpty }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

// MARK: - Supabase helpers
import Supabase

private struct CategoryNameRow: Decodable { let name: String }
private struct ProductCategoryEmbed: Decodable { let name: String }
private struct ProductWithCategoryRow: Decodable { let product_category: ProductCategoryEmbed? }

private extension CategoryFilterView {
    func fetchCategoryNamesFromCategoryTable() async throws -> [String] {
        let client = SupabaseManager.shared.client
        let rows: [CategoryNameRow] = try await client
            .from("product_category")
            .select("name")
            .execute()
            .value
        return rows.map { $0.name }
    }

    func fetchCategoryNamesFromProductsJoin() async throws -> [String] {
        let client = SupabaseManager.shared.client
        let rows: [ProductWithCategoryRow] = try await client
            .from("products")
            .select("product_category:product_category_id(name)")
            .execute()
            .value
        return rows.compactMap { $0.product_category?.name }
    }
}

// MARK: - Preview
struct CategoryFilterView_Previews: PreviewProvider {
    @State static var selected: String? = nil
    static var previews: some View {
        CategoryFilterView(selectedCategory: $selected)
            .environmentObject(AuthViewModel())
    }
}
