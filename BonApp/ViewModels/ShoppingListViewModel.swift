import Foundation
import Supabase

// MARK: - DTOs
struct ShoppingListItemDTO: Identifiable, Hashable, Decodable {
    let productId: Int
    let count: Double
    let isBought: Bool
    let shoppingListId: UUID
    let productName: String
    let productCategoryId: Int?
    var id: String { "\(shoppingListId.uuidString)-\(productId)" }

    init(
        productId: Int,
        count: Double,
        isBought: Bool,
        shoppingListId: UUID,
        productName: String,
        productCategoryId: Int?
    ) {
        self.productId = productId
        self.count = count
        self.isBought = isBought
        self.shoppingListId = shoppingListId
        self.productName = productName
        self.productCategoryId = productCategoryId
    }

    private enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case count
        case isBought = "is_bought"
        case shoppingListId = "shopping_list_id"
        case product
    }

    private struct ProductEmbed: Decodable { let id: Int; let name: String; let product_category_id: Int? }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        productId = try c.decode(Int.self, forKey: .productId)
        count = try c.decode(Double.self, forKey: .count)
        isBought = try c.decode(Bool.self, forKey: .isBought)
        shoppingListId = try c.decode(UUID.self, forKey: .shoppingListId)
        let p = try c.decode(ProductEmbed.self, forKey: .product)
        productName = p.name
        productCategoryId = p.product_category_id
    }
}

private struct ProductOnListInsert: Encodable {
    let shopping_list_id: UUID
    let product_id: Int
    let count: Double
    let is_bought: Bool
}

private struct ProductOnListUpdate: Encodable {
    let count: Double?
    let is_bought: Bool?
}

private struct PantryInsert: Encodable {
    let user_id: String
    let product_id: Int
    let quantity: Double
}

private struct PantryUpdate: Encodable {
    let quantity: Double
}

final class ShoppingListViewModel: ObservableObject {
    @Published var items: [ShoppingListItemDTO] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    private let client = SupabaseManager.shared.client
    private let userId: String?
    private let shoppingListId: UUID

    // MARK: - Init
    init(ownerId: String?, shoppingListId: UUID) {
        self.userId = ownerId
        self.shoppingListId = shoppingListId
        Task { await fetchItems() }
    }

    // MARK: - Fetch
    @MainActor
    func fetchItems() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Nie musimy tu filtrować po userId, lista jest już jednoznacznie określona przez shoppingListId
            let rawRows: [ShoppingListItemDTO] = try await client
                .from("product_on_list")
                .select("product_id,count,is_bought,shopping_list_id,product:product_id(id,name,product_category_id)")
                .eq("shopping_list_id", value: shoppingListId)
                .order("is_bought", ascending: true)
                .order("product_id", ascending: true)
                .execute()
                .value

            // Scal powtarzające się produkty (ten sam product_id) sumując ilości
            let grouped = Dictionary(grouping: rawRows, by: { $0.productId })

            let merged: [ShoppingListItemDTO] = grouped.values.compactMap { group -> ShoppingListItemDTO? in
                guard let first = group.first else { return nil }
                let totalCount = group.reduce(0.0) { $0 + $1.count }
                // jeżeli choć jeden wpis NIE jest kupiony, traktujemy całość jako niekupioną
                let allBought = group.allSatisfy { $0.isBought }

                return ShoppingListItemDTO(
                    productId: first.productId,
                    count: totalCount,
                    isBought: allBought,
                    shoppingListId: first.shoppingListId,
                    productName: first.productName,
                    productCategoryId: first.productCategoryId
                )
            }

            // Najpierw niekupione, potem kupione; w ramach grupy sortujemy alfabetycznie
            self.items = merged.sorted {
                if $0.isBought == $1.isBought {
                    return $0.productName < $1.productName
                } else {
                    return !$0.isBought && $1.isBought
                }
            }
        } catch {
            self.error = error.localizedDescription
            self.items = []
        }
    }

    // MARK: - Add
    func addItem(productId: Int, quantity: Double) async {
        do {
            struct Existing: Decodable { let count: Double }
            let existing: [Existing] = try await client
                .from("product_on_list")
                .select("count")
                .eq("shopping_list_id", value: shoppingListId)
                .eq("product_id", value: productId)
                .limit(1)
                .execute()
                .value

            if let row = existing.first {
                let newCount = row.count + quantity
                let payload = ProductOnListUpdate(count: newCount, is_bought: nil)
                _ = try await client
                    .from("product_on_list")
                    .update(payload)
                    .eq("shopping_list_id", value: shoppingListId)
                    .eq("product_id", value: productId)
                    .execute()
            } else {
                let payload = ProductOnListInsert(shopping_list_id: shoppingListId, product_id: productId, count: quantity, is_bought: false)
                _ = try await client.from("product_on_list").insert(payload).execute()
            }
            await fetchItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Update
    func updateItem(productId: Int, quantity: Double) async {
        let payload = ProductOnListUpdate(count: quantity, is_bought: nil)
        do {
            _ = try await client
                .from("product_on_list")
                .update(payload)
                .eq("shopping_list_id", value: shoppingListId)
                .eq("product_id", value: productId)
                .execute()
            await fetchItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Delete
    func deleteItem(productId: Int) async {
        do {
            _ = try await client
                .from("product_on_list")
                .delete()
                .eq("shopping_list_id", value: shoppingListId)
                .eq("product_id", value: productId)
                .execute()
            await fetchItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Mark as bought
    func markAsBought(productId: Int) async {
        do {
            _ = try await client
                .from("product_on_list")
                .update(ProductOnListUpdate(count: nil, is_bought: true))
                .eq("shopping_list_id", value: shoppingListId)
                .eq("product_id", value: productId)
                .execute()
            await fetchItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Transfer bought items to pantry
    func transferBoughtItemsToPantry() async {
        do {
            struct Row: Decodable { let product_id: Int; let count: Double }
            struct Existing: Decodable { let id: UUID; let quantity: Double }

            // Pobierz wszystkie kupione pozycje z listy
            let rows: [Row] = try await client
                .from("product_on_list")
                .select("product_id,count")
                .eq("shopping_list_id", value: shoppingListId)
                .eq("is_bought", value: true)
                .execute()
                .value
            guard !rows.isEmpty else { return }

            // Ustal aktualne UID
            var effectiveUid = userId
            if effectiveUid == nil || effectiveUid?.isEmpty == true {
                if let session = try? await client.auth.session {
                    effectiveUid = session.user.id.uuidString
                }
            }
            guard let uid = effectiveUid, !uid.isEmpty else { return }

            // Dla każdego produktu albo zaktualizuj istniejący rekord w pantry, albo wstaw nowy
            for row in rows {
                let existing: [Existing] = try await client
                    .from("pantry")
                    .select("id,quantity")
                    .eq("user_id", value: uid)
                    .eq("product_id", value: row.product_id)
                    .limit(1)
                    .execute()
                    .value

                if let current = existing.first {
                    let newQuantity = current.quantity + row.count
                    let payload = PantryUpdate(quantity: newQuantity)
                    _ = try await client
                        .from("pantry")
                        .update(payload)
                        .eq("id", value: current.id)
                        .execute()
                } else {
                    let payload = PantryInsert(user_id: uid, product_id: row.product_id, quantity: row.count)
                    _ = try await client
                        .from("pantry")
                        .insert(payload)
                        .execute()
                }
            }

            // Usuń z listy wszystkie kupione pozycje
            _ = try await client
                .from("product_on_list")
                .delete()
                .eq("shopping_list_id", value: shoppingListId)
                .eq("is_bought", value: true)
                .execute()

            await fetchItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Refresh
    func refresh() async { await fetchItems() }
}

// MARK: - Shopping lists (containers) – for the screen that shows user's lists

struct ShoppingListDTO: Identifiable, Hashable, Decodable {
    let id: UUID
    let name: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case userId = "user_id"
    }
}

private struct ShoppingListInsert: Encodable {
    let name: String
    let user_id: String
}

final class ShoppingListsViewModel: ObservableObject {
    @Published var lists: [ShoppingListDTO] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    private let client = SupabaseManager.shared.client
    private let userId: String?

    init(ownerId: String?) {
        self.userId = ownerId
        Task { await fetchLists() }
    }

    // MARK: - Fetch lists
    @MainActor
    func fetchLists() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            var effectiveUid: String? = userId
            if effectiveUid == nil || effectiveUid?.isEmpty == true {
                if let session = try? await client.auth.session {
                    effectiveUid = session.user.id.uuidString
                }
            }

            let base = client
                .from("shopping_list")
                .select("id,name,user_id")

            let filtered: PostgrestTransformBuilder = {
                if let uid = effectiveUid, !uid.isEmpty {
                    return base.eq("user_id", value: uid)
                } else {
                    return base
                }
            }()

            let rows: [ShoppingListDTO] = try await filtered
                .order("name", ascending: true)
                .execute()
                .value
            self.lists = rows
        } catch {
            self.error = error.localizedDescription
            self.lists = []
        }
    }

    // MARK: - Create list
    func createList(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Ustal poprawne UID (najpierw z ownerId, a jeśli puste – z aktualnej sesji)
        var effectiveUid: String? = userId
        if effectiveUid == nil || effectiveUid?.isEmpty == true {
            if let session = try? await client.auth.session {
                effectiveUid = session.user.id.uuidString
            }
        }

        guard let uid = effectiveUid, !uid.isEmpty else {
            await MainActor.run {
                self.error = "Brak zalogowanego użytkownika – nie można utworzyć listy."
            }
            return
        }

        let payload = ShoppingListInsert(name: trimmed, user_id: uid)

        do {
            _ = try await client
                .from("shopping_list")
                .insert(payload)
                .execute()
            await fetchLists()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Delete list
    func deleteList(id: UUID) async {
        // Ustal poprawne UID (najpierw z ownerId, a jeśli puste – z aktualnej sesji)
        var effectiveUid: String? = userId
        if effectiveUid == nil || effectiveUid?.isEmpty == true {
            if let session = try? await client.auth.session {
                effectiveUid = session.user.id.uuidString
            }
        }

        guard let uid = effectiveUid, !uid.isEmpty else {
            await MainActor.run {
                self.error = "Brak zalogowanego użytkownika – nie można usunąć listy."
            }
            return
        }

        do {
            // Remove child rows first to satisfy FK constraints
            _ = try await client
                .from("product_on_list")
                .delete()
                .eq("shopping_list_id", value: id)
                .execute()

            _ = try await client
                .from("shopping_list")
                .delete()
                .eq("id", value: id)
                .eq("user_id", value: uid)
                .execute()
            await fetchLists()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Refresh
    func refresh() async { await fetchLists() }
}
