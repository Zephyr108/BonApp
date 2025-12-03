//
//  BonAppUITests.swift
//  BonAppUITests
//
//  Created by Marcin on 28/04/2025.
//

import XCTest

final class BonAppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launch()

        // Jeśli widoczny ekran logowania → zaloguj testowego użytkownika
        if app.textFields["emailField"].exists {
            loginTestUser(app)
        }

        // Czekamy aż główny ekran się pojawi po zalogowaniu
        XCTAssertTrue(
            app.buttons["Przepisy"].waitForExistence(timeout: 5),
            "Ekran główny nie pojawił się po starcie aplikacji"
        )
    }

    // MARK: - Pomocnicza funkcja logowania testowego użytkownika
    private func loginTestUser(_ app: XCUIApplication) {
        let email = "test@example.com"
        let password = "Test123!"

        let emailField = app.textFields["emailField"]
        let passwordField = app.secureTextFields["passwordField"]
        let loginButton = app.buttons["loginButton"]

        XCTAssertTrue(emailField.exists, "Pole email nie istnieje")
        XCTAssertTrue(passwordField.exists, "Pole hasła nie istnieje")

        emailField.tap()
        emailField.clearAndTypeText(email)

        passwordField.tap()
        passwordField.clearAndTypeText(password)

        loginButton.tap()
    }

    // MARK: - TESTY UI

    @MainActor
    func testInitialScreenShowsRecipesSection() throws {
        let app = XCUIApplication()
        XCTAssertTrue(app.buttons["Przepisy użytkowników"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testNavigateToRecipesList() throws {
        let app = XCUIApplication()
        app.buttons["Przepisy"].tap()
        XCTAssertTrue(app.navigationBars.element.exists)
    }

    @MainActor
    func testOpenSearchView() throws {
        let app = XCUIApplication()
        app.buttons["Szukaj"].tap()
        XCTAssertTrue(app.searchFields.element.exists)
    }

    @MainActor
    func testOpenFirstRecipeDetails() throws {
        let app = XCUIApplication()
        XCTAssertTrue(app.cells.element(boundBy: 0).waitForExistence(timeout: 3))
        app.cells.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Kroki"].exists)
    }

    @MainActor
    func testNavigateToAccountTab() throws {
        let app = XCUIApplication()

        let kontoTab = app.tabBars.buttons
            .containing(NSPredicate(format: "label CONTAINS[c] %@", "Konto"))
            .firstMatch

        guard kontoTab.waitForExistence(timeout: 5) else {
            throw XCTSkip("Zakładka Konto niedostępna — możliwe że nie jesteś zalogowany.")
        }

        kontoTab.tap()

        XCTAssertTrue(
            kontoTab.isSelected ||
            app.staticTexts["Twoje konto"].waitForExistence(timeout: 3),
            "Zakładka Konto nie została poprawnie otwarta"
        )
    }
}


// MARK: - Przydatne rozszerzenie do czyszczenia pól tekstowych
extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        tap()
        if let string = value as? String {
            let deleteString = string.map { _ in XCUIKeyboardKey.delete.rawValue }.joined()
            typeText(deleteString)
        }
        typeText(text)
    }
}
