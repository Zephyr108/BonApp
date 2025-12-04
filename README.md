# 🍽️ BonApp – Nowoczesna aplikacja mobilna do przepisów, list zakupów i zarządzania spiżarnią

**BonApp** to aplikacja iOS stworzona w **SwiftUI**, która ułatwia organizację kuchni: dodawanie przepisów, tworzenie list zakupów, zarządzanie produktami w spiżarni oraz odkrywanie rekomendacji.  
Aplikacja korzysta z **Supabase** jako backendu oraz architektury **MVVM**.

---

## 🚀 Funkcje aplikacji

### 🔐 Autoryzacja & konto użytkownika
- Logowanie i rejestracja przez Supabase Auth  
- Ekran onboarding + ustawianie profilu  
- Zarządzanie kontem użytkownika  

### 📚 Przepisy
- Dodawanie, edycja i przegląd własnych przepisów  
- Wyszukiwarka  
- Kategorie, składniki, zdjęcia  
- Reużywalne komponenty: `RecipeRowView`, `IngredientsListView`

### 🛒 Listy zakupów
- Tworzenie wielu list  
- Dodawanie, usuwanie, odhaczanie produktów  
- Szczegółowy widok listy zakupów  

### 🧺 Spiżarnia / Pantry
- Dodawanie produktów (nazwa, kategoria, data ważności)  
- Edycja produktów  
- Wyświetlanie kategorii  

### 🧠 Rekomendacje
- Widok rekomendacji: `RecommendationsView`  
- Logika w `RecommendationsViewModel`  

### 🌍 Wielojęzyczność
- Obsługa `Localizable.strings`  

---

## 🔧 Technologie i architektura

### Platforma
- iOS 17+  
- SwiftUI  
- Swift 5+

### Backend
- Supabase Auth + Database  
- Warstwa komunikacji: `SupabaseManager.swift`

### Architektura
- MVVM  
- Struktura katalogów:
  - `Views/`
  - `ViewModels/`
  - `Components/`
  - `Utils/`

### Testy
- `BonAppTests`  
- `BonAppUITests`  

---

## 📁 Struktura projektu

```
BonApp
│
├── BonAppApp.swift
├── ContentView.swift
├── SupabaseManager.swift
│
├── ViewModels/
│
├── Views/
│   ├── Auth/
│   ├── Account/
│   ├── Recipes/
│   ├── Pantry/
│   ├── ShoppingList/
│   ├── Recommendations/
│   └── Components/
│
└── Utils/
```

---

## 🧪 Plany rozwoju
- Powiadomienia o kończących się produktach  
- Inteligentne filtrowanie przepisów na podstawie spiżarni  
- Tryb gotowania krok-po-kroku  
- Udostępnianie list zakupów  
- Planowanie posiłków  

---

## ▶️ Uruchomienie projektu

1. Pobierz repozytorium  
2. Otwórz `BonApp.xcodeproj`  
3. Uzupełnij w `SupabaseManager.swift`:  
   - `SUPABASE_URL`  
   - `SUPABASE_ANON_KEY`  
4. Uruchom aplikację  

---

## 📄 Licencja
Projekt edukacyjny – użycie komercyjne wymaga zgody autora.
