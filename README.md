# 🍽️ BonApp – Aplikacja Mobilna do Przechowywania Przepisów i List Zakupów

**BonApp** to nowoczesna aplikacja mobilna stworzona z użyciem **SwiftUI**, umożliwiająca użytkownikom zarządzanie przepisami kulinarnymi, listą zakupów oraz zawartością spiżarni. Ułatwia planowanie posiłków i organizację produktów spożywczych.

---

## 🔧 Technologie

**Platforma:**
- 📱 SwiftUI (iOS)
- 💾 CoreData (local persistence)
- 🌐 Localizable.strings (obsługa wielu języków)

**Architektura:**
- 🧠 MVVM (Model-View-ViewModel)

---

## 📁 Struktura projektu

```
BonApp/
├── Models/
│   ├── PantryItem+CoreDataClass.swift
│   ├── Recipe+CoreDataClass.swift
│   ├── RecipeStep+CoreDataClass.swift
│   ├── ShoppingItem+CoreDataClass.swift
│   └── User+CoreDataClass.swift
│   └── (pliki +Properties.swift)
├── Resources/
│   └── Localizable.strings
├── Utils/
│   ├── Extensions.swift
│   ├── GestureHandler.swift
│   ├── ImagePicker.swift
│   └── Validators.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── PantryViewModel.swift
│   ├── RecipeViewModel.swift
│   ├── RecommendationsViewModel.swift
│   ├── SettingsViewModel.swift
│   └── ShoppingListViewModel.swift
├── Views/
│   ├── Account/
│   │   └── SettingsView.swift
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   ├── ProfileSetupView.swift
│   │   └── RegistrationView.swift
│   ├── Components/
│   │   ├── CategoryFilterView.swift
│   │   ├── IngredientsListView.swift
│   │   └── RecipeRowView.swift
│   ├── Pantry/
│   │   ├── AddPantryItemView.swift
│   │   ├── EditPantryItemView.swift
│   │   └── PantryView.swift
│   ├── Recipes/
│   │   ├── AddRecipeView.swift
│   │   ├── EditRecipeView.swift
│   │   ├── RecipeDetailView.swift
│   │   ├── RecipeListView.swift
│   │   └── RecipeSearchView.swift
│   ├── Recommendations/
│   │   └── RecommendationsView.swift
│   └── ShoppingList/
│       ├── AddShoppingItemView.swift
│       ├── EditShoppingItemView.swift
│       └── ShoppingListView.swift
├── Assets/
├── LaunchScreen.storyboard
├── BonAppApp.swift
├── ContentView.swift
└── Persistence.swift
```

---

## 🚀 Uruchomienie aplikacji

### 📱 Wymagania

- Xcode 14 lub nowszy
- iOS 15+

### ▶️ Kroki

1. Otwórz `BonApp.xcodeproj` lub `BonApp.xcworkspace` w Xcode.
2. Wybierz emulator lub podłączone urządzenie.
3. Kliknij ▶️ **Run**.

> ℹ️ Brak backendu – dane przechowywane są lokalnie na urządzeniu użytkownika.

---

## 👤 Funkcjonalności użytkownika

1. 🧾 Przeglądanie, dodawanie i edycja przepisów
2. 🛒 Tworzenie i aktualizowanie listy zakupów
3. 🥫 Zarządzanie produktami w spiżarni
4. 🧠 Propozycje potraw na podstawie zawartości spiżarni
5. 🔐 System logowania i rejestracji (lokalny)

---

## 🌱 Możliwe rozszerzenia

- ☁️ Synchronizacja z chmurą (np. Firebase, iCloud)
- 🧪 Składnikowe filtrowanie przepisów
- 📅 Planer tygodniowy
- 🔔 Powiadomienia o kończących się produktach
- 👨‍🍳 Tryb gotowania (krok po kroku)

---

## 📄 Licencja

Projekt do celów edukacyjnych – jeśli chcesz użyć go komercyjnie, skontaktuj się z autorem 😊

---
