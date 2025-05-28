//
//  CategoryFilterView.swift
//  BonApp
//
//  Created by Marcin on 28/04/2025.
//

import SwiftUI

struct CategoryFilterView: View {
    let categories: [String]
    @Binding var selectedCategory: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        // Toggle selection
                        if selectedCategory == category {
                            selectedCategory = nil
                        } else {
                            selectedCategory = category
                        }
                    }) {
                        Text(category)
                            .font(.subheadline)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedCategory == category ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                            )
                    }
                    .foregroundColor(selectedCategory == category ? .accentColor : .primary)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CategoryFilterView_Previews: PreviewProvider {
    @State static var selected: String? = nil
    static var previews: some View {
        CategoryFilterView(
            categories: ["Wszystkie", "Nabiał", "Mięso", "Warzywa", "Pieczywo"],
            selectedCategory: $selected
        )
    }
}

//To do
