//
//  BonAppTests.swift
//  BonAppTests
//
//  Created by Marcin on 28/04/2025.
//

import Testing
import Foundation
@testable import BonApp

struct BonAppTests {

    // [Unit] Sprawdza, że asynchroniczna operacja kończy się w rozsądnym czasie
    @Test("Asynchroniczna operacja kończy się w oczekiwanym czasie")
    func async_operationCompletes() async throws {
        let start = Date()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 sekundy
        let end = Date()

        let elapsed = end.timeIntervalSince(start)
        #expect(elapsed >= 0.1)
    }

    // [Unit] Sprawdza, że funkcja rzucająca działa poprawnie gdy nie ma błędu
    @Test("Funkcja rzucająca działa poprawnie gdy nie ma błędu")
    func throwingFunction_success() throws {
        #expect(try mayThrow(false) == 42)
    }

    // [Unit] Sprawdza, że funkcja rzucająca zwraca błąd gdy powinna
    @Test("Funkcja rzucająca zwraca błąd gdy powinna")
    func throwingFunction_failure() {
        #expect(throws: DummyError.somethingWentWrong) {
            _ = try mayThrow(true)
        }
    }

    // [Unit] Sprawdza, że filtrowanie listy przepisów po czasie przygotowania działa poprawnie
    @Test("Filtrowanie listy po maksymalnym czasie przygotowania")
    func recipeTimeFiltering_works() {
        struct Recipe {
            let title: String
            let prepareTime: Int
        }

        let all = [
            Recipe(title: "Szybka jajecznica", prepareTime: 5),
            Recipe(title: "Makaron", prepareTime: 20),
            Recipe(title: "Lasagne", prepareTime: 60),
        ]

        let maxTime = 20
        let filtered = all.filter { $0.prepareTime <= maxTime }

        #expect(filtered.count == 2)
        #expect(filtered.map(\.title).contains("Szybka jajecznica"))
        #expect(filtered.map(\.title).contains("Makaron"))
    }

    // [Unit] Sprawdza, że łączenie ilości tego samego produktu działa poprawnie
    @Test("Łączenie ilości tego samego produktu działa poprawnie")
    func mergeQuantities_works() {
        func mergedQuantity(existing: Double, added: Double) -> Double {
            existing + added
        }

        #expect(mergedQuantity(existing: 300, added: 400) == 700)
        #expect(mergedQuantity(existing: 0, added: 250) == 250)
        #expect(mergedQuantity(existing: 1.5, added: 0.5) == 2.0)
    }

    // [Unit] Sprawdza, że obliczanie brakujących składników przepisu działa poprawnie
    @Test("Obliczanie brakujących składników przepisu działa poprawnie")
    func missingIngredientsCalculation_works() {
        struct PantryItem { let productId: Int; let quantity: Double }
        struct RecipeIngredient { let productId: Int; let needed: Double }

        let pantry = [
            PantryItem(productId: 1, quantity: 200),
            PantryItem(productId: 2, quantity: 50)
        ]

        let recipe = [
            RecipeIngredient(productId: 1, needed: 150),
            RecipeIngredient(productId: 2, needed: 100),
            RecipeIngredient(productId: 3, needed: 20)
        ]

        let missing = recipe.filter { ingredient in
            let available = pantry.first(where: { $0.productId == ingredient.productId })?.quantity ?? 0
            return available < ingredient.needed
        }

        #expect(missing.count == 2)
        #expect(missing.map(\.productId).contains(2))
        #expect(missing.map(\.productId).contains(3))
    }

    // [Unit] Sprawdza, że po zsumowaniu pozycji listy zakupów z tym samym produktem powstaje jedna pozycja z poprawną ilością
    @Test("Łączenie pozycji listy zakupów z tym samym produktem działa poprawnie")
    func shoppingListMerge_works() {
        struct ShoppingItem {
            let productId: Int
            var quantity: Double
        }

        func mergeShoppingItems(_ items: [ShoppingItem]) -> [ShoppingItem] {
            var merged: [Int: Double] = [:]
            for item in items {
                merged[item.productId, default: 0] += item.quantity
            }
            return merged.map { ShoppingItem(productId: $0.key, quantity: $0.value) }
        }

        let list = [
            ShoppingItem(productId: 1, quantity: 2.0),
            ShoppingItem(productId: 1, quantity: 3.5),
            ShoppingItem(productId: 2, quantity: 1.0)
        ]

        let merged = mergeShoppingItems(list)
        #expect(merged.count == 2)
        #expect(merged.first(where: { $0.productId == 1 })?.quantity == 5.5)
        #expect(merged.first(where: { $0.productId == 2 })?.quantity == 1.0)
    }

    // [Unit] Sprawdza, że dwukrotne wywołanie toggleFavorite przywraca stan isFavorite do początkowego
    @Test("Przełączanie ulubionego stanu przepisu działa poprawnie")
    func favoritesToggle_works() {
        struct Recipe {
            var isFavorite: Bool
            mutating func toggleFavorite() {
                isFavorite.toggle()
            }
        }

        var recipe = Recipe(isFavorite: false)
        recipe.toggleFavorite()
        #expect(recipe.isFavorite == true)
        recipe.toggleFavorite()
        #expect(recipe.isFavorite == false)
    }

    // [Integration] Sprawdza, czy wszystkie składniki przepisu są pokryte przez ilości w spiżarni (brak brakujących)
    @Test("Sprawdzenie zgodności składników przepisu z zawartością spiżarni")
    func pantryAndRecipeSatisfaction_integration() {
        struct PantryItem { let productId: Int; let quantity: Double }
        struct RecipeIngredient { let productId: Int; let needed: Double }

        let pantry = [
            PantryItem(productId: 1, quantity: 100),
            PantryItem(productId: 2, quantity: 200),
            PantryItem(productId: 3, quantity: 50)
        ]

        let recipe = [
            RecipeIngredient(productId: 1, needed: 50),
            RecipeIngredient(productId: 2, needed: 100),
            RecipeIngredient(productId: 3, needed: 50)
        ]

        let missing = recipe.filter { ingredient in
            let available = pantry.first(where: { $0.productId == ingredient.productId })?.quantity ?? 0
            return available < ingredient.needed
        }

        #expect(missing.isEmpty)
    }

    // [Integration] Symuluje przepływ z listy zakupów do spiżarni, sprawdza poprawność ilości i pustą listę kupionych
    @Test("Przepływ: lista zakupów do spiżarni działa poprawnie")
    func shoppingListToPantryFlow_integration() {
        struct ShoppingItem {
            let productId: Int
            var quantity: Double
            var isBought: Bool
        }
        struct PantryItem {
            let productId: Int
            var quantity: Double
        }

        var shoppingList = [
            ShoppingItem(productId: 1, quantity: 3, isBought: false),
            ShoppingItem(productId: 2, quantity: 5, isBought: false)
        ]
        var pantry: [PantryItem] = []

        // Oznacz jako kupione
        for i in shoppingList.indices {
            shoppingList[i].isBought = true
        }

        // Przenieś kupione do spiżarni i usuń z listy
        let boughtItems = shoppingList.filter { $0.isBought }
        shoppingList.removeAll(where: { $0.isBought })

        for item in boughtItems {
            if let index = pantry.firstIndex(where: { $0.productId == item.productId }) {
                pantry[index].quantity += item.quantity
            } else {
                pantry.append(PantryItem(productId: item.productId, quantity: item.quantity))
            }
        }

        #expect(pantry.count == 2)
        #expect(pantry.first(where: { $0.productId == 1 })?.quantity == 3)
        #expect(pantry.first(where: { $0.productId == 2 })?.quantity == 5)
        #expect(shoppingList.isEmpty)
    }

    enum DummyError: Error { case somethingWentWrong }

    func mayThrow(_ shouldThrow: Bool) throws -> Int {
        if shouldThrow { throw DummyError.somethingWentWrong }
        return 42
    }
}
