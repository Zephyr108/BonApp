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

    /// Przykładowy prosty test logiki (test synchroniczny)
    @Test("Dodawanie działa poprawnie")
    func addition_works() {
        let result = 2 + 3
        #expect(result == 5)
    }

    /// Przykład testu asynchronicznego (np. symulacja zapytania sieciowego)
    @Test("Asynchroniczna operacja kończy się w oczekiwanym czasie")
    func async_operationCompletes() async throws {
        let start = Date()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 sekundy
        let end = Date()

        let elapsed = end.timeIntervalSince(start)
        #expect(elapsed >= 0.1)
    }

    /// Przykład testu rzucającego błąd i sprawdzającego wynik
    enum DummyError: Error { case somethingWentWrong }

    func mayThrow(_ shouldThrow: Bool) throws -> Int {
        if shouldThrow { throw DummyError.somethingWentWrong }
        return 42
    }

    @Test("Funkcja rzucająca działa poprawnie gdy nie ma błędu")
    func throwingFunction_success() throws {
        #expect(try mayThrow(false) == 42)
    }

    @Test("Funkcja rzucająca zwraca błąd gdy powinna")
    func throwingFunction_failure() {
        #expect(throws: DummyError.somethingWentWrong) {
            _ = try mayThrow(true)
        }
    }

    /// Przykład testu filtrowania przepisów po czasie przygotowania
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

    /// Przykład testu łączenia ilości produktów (np. w spiżarni)
    @Test("Łączenie ilości tego samego produktu działa poprawnie")
    func mergeQuantities_works() {
        func mergedQuantity(existing: Double, added: Double) -> Double {
            existing + added
        }

        #expect(mergedQuantity(existing: 300, added: 400) == 700)
        #expect(mergedQuantity(existing: 0, added: 250) == 250)
        #expect(mergedQuantity(existing: 1.5, added: 0.5) == 2.0)
    }
}
