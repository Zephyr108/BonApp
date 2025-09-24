import Foundation
import Supabase

// MARK: - DTOs
struct ShoppingListItemDTO: Identifiable, Hashable, Decodable {
    let id: UUID
    let productId: Int
    let quantity: Double
    let isBought: Bool
    let userId: String
    let productName: String
    let productCategoryId: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case quantity
        case isBought = "is_bought"
        case userId = "user_id"
        case product
    }

    private struct ProductEmbed: Decodable { let id: Int; let name: String; let product_category_id: Int? }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        productId = try c.decode(Int.self, forKey: .productId)
        quantity = try c.decode(Double.self, forKey: .quantity)
        isBought = try c.decode(Bool.self, forKey: .isBought)
        userId = try c.decode(String.self, forKey: .userId)
        let p = try c.decode(ProductEmbed.self, forKey: .product)
        productName = p.name
        productCategoryId = p.product_category_id
    }
}

private struct ShoppingInsert: Encodable {
    let user_id: String
    let product_id: Int
    let quantity: Double
    let is_bought: Bool
}

private struct ShoppingUpdate: Encodable {
    let product_id: Int
    let quantity: Double
}

private struct BoughtUpdate: Encodable { let is_bought: Bool }

private struct PantryInsert: Encodable {
    let user_id: String
    let product_id: Int
    let quantity: Double
}

final class ShoppingListViewModel: ObservableObject {
    @Published var items: [ShoppingListItemDTO] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    private let client = SupabaseManager.shared.client
    private let userId: String

    // MARK: - Init
    init(ownerId: String) { // keep external API stable
        self.userId = ownerId
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
            let rows: [ShoppingListItemDTO] = try await client
                .from("shopping_list")
                .select("id,product_id,quantity,is_bought,user_id,product:product_id(id,name,product_category_id)")
                .eq("user_id", value: userId)
                .order("is_bought", ascending: true)
                .order("id", ascending: true)
                .execute()
                .value
            self.items = rows
        } catch {
            self.error = error.localizedDescription
            self.items = []
        }
    }

    // MARK: - Add
    func addItem(productId: Int, quantity: Double) async {
        let payload = ShoppingInsert(user_id: userId, product_id: productId, quantity: quantity, is_bought: false)
        do {
            _ = try await client.from("shopping_list").insert(payload).execute()
            await fetchItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Update
    func updateItem(id: UUID, productId: Int, quantity: Double) async {
        let payload = ShoppingUpdate(product_id: productId, quantity: quantity)
        do {
            _ = try await client
                .from("shopping_list")
                .update(payload)
                .eq("id", value: id)
                .eq("user_id", value: userId)
                .execute()
            await fetchItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Delete
    func deleteItem(id: UUID) async {
        do {
            _ = try await client
                .from("shopping_list")
                .delete()
                .eq("id", value: id)
                .eq("user_id", value: userId)
                .execute()
            await fetchItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Mark as bought
    func markAsBought(id: UUID) async {
        do {
            _ = try await client
                .from("shopping_list")
                .update(BoughtUpdate(is_bought: true))
                .eq("id", value: id)
                .eq("user_id", value: userId)
                .execute()
            await fetchItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Transfer bought items to pantry
    func transferBoughtItemsToPantry() async {
        do {
            struct Row: Decodable { let id: UUID; let product_id: Int; let quantity: Double }
            let rows: [Row] = try await client
                .from("shopping_list")
                .select("id,product_id,quantity")
                .eq("user_id", value: userId)
                .eq("is_bought", value: true)
                .execute()
                .value
            guard !rows.isEmpty else { return }

            let pantryPayload: [PantryInsert] = rows.map { r in
                PantryInsert(user_id: userId, product_id: r.product_id, quantity: r.quantity)
            }
            _ = try await client
                .from("pantry")
                .insert(pantryPayload)
                .execute()

            let ids = rows.map { $0.id }
            _ = try await client
                .from("shopping_list")
                .delete()
                .in("id", values: ids)
                .eq("user_id", value: userId)
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
    private let userId: String

    init(ownerId: String) {
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
            let rows: [ShoppingListDTO] = try await client
                .from("shopping_list")
                .select("id,name,user_id")
                .eq("user_id", value: userId)
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
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let payload = ShoppingListInsert(name: name, user_id: userId)
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
        do {
            _ = try await client
                .from("shopping_list")
                .delete()
                .eq("id", value: id)
                .eq("user_id", value: userId)
                .execute()
            await fetchLists()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Refresh
    func refresh() async { await fetchLists() }
}
