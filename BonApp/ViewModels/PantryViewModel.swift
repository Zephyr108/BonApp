import Foundation
import Supabase

/*
struct PantryItemDTO: Identifiable, Hashable, Decodable {
    let id: UUID
    let quantity: Double
    let userId: String
    let productId: Int
    let productName: String
    let productCategoryId: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case quantity
        case userId = "user_id"
        case productId = "product_id"
        case product
    }

    private struct ProductEmbed: Decodable { let id: Int; let name: String; let product_category_id: Int? }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        quantity = try c.decode(Double.self, forKey: .quantity)
        userId = try c.decode(String.self, forKey: .userId)
        productId = try c.decode(Int.self, forKey: .productId)
        let p = try c.decode(ProductEmbed.self, forKey: .product)
        productName = p.name
        productCategoryId = p.product_category_id
    }
}
*/
/*
final class PantryViewModel: ObservableObject {
    @Published var pantryItems: [PantryItemDTO] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    private let client = SupabaseManager.shared.client
    private let userId: String

    init(userId: String) {
        self.userId = userId
        Task { await fetchPantryItems() }
    }

    // MARK: - Fetch
    @MainActor
    func fetchPantryItems() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let rows: [PantryItemDTO] = try await client
                .from("pantry")
                .select("id,quantity,user_id,product_id,product:product_id(id,name,product_category_id)")
                .eq("user_id", value: userId)
                .order("id", ascending: true)
                .execute()
                .value
            self.pantryItems = rows
        } catch {
            self.error = error.localizedDescription
            self.pantryItems = []
        }
    }

    // MARK: - Add
    @MainActor
    func addItem(productId: Int, quantity: Double) async {
        struct InsertPayload: Encodable { let user_id: String; let product_id: Int; let quantity: Double }
        let payload = InsertPayload(user_id: userId, product_id: productId, quantity: quantity)
        do {
            _ = try await client.from("pantry").insert(payload).execute()
            await fetchPantryItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Update
    @MainActor
    func updateItem(id: UUID, productId: Int, quantity: Double) async {
        struct UpdatePayload: Encodable { let product_id: Int; let quantity: Double }
        let payload = UpdatePayload(product_id: productId, quantity: quantity)
        do {
            _ = try await client
                .from("pantry")
                .update(payload)
                .eq("id", value: id)
                .eq("user_id", value: userId)
                .execute()
            await fetchPantryItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Delete
    @MainActor
    func deleteItem(id: UUID) async {
        do {
            _ = try await client
                .from("pantry")
                .delete()
                .eq("id", value: id)
                .eq("user_id", value: userId)
                .execute()
            await fetchPantryItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func refresh() async { await fetchPantryItems() }
}
*/

// MARK: - DTO
struct PantryItemRow: Identifiable, Decodable, Hashable {
    let id: UUID
    let productId: Int
    let productName: String
    let quantity: Double
    let productUnit: String?
    let productCategoryId: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case quantity
        case product
    }

    private struct ProductEmbed: Decodable {
        let id: Int
        let name: String
        let product_category_id: Int?
        let unit: String?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        productId = try c.decode(Int.self, forKey: .productId)
        quantity = try c.decode(Double.self, forKey: .quantity)
        let p = try c.decode(ProductEmbed.self, forKey: .product)
        productName = p.name
        productCategoryId = p.product_category_id
        productUnit = p.unit
    }
}

final class PantryViewModel: ObservableObject {
    @Published var pantryItems: [PantryItemRow] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    private let client = SupabaseManager.shared.client
    private var userId: String? = nil
    func setUserId(_ id: String?) { self.userId = id }

    @MainActor
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            guard let uidStr = userId, let uid = UUID(uuidString: uidStr) else { self.pantryItems = []; return }
            let rows: [PantryItemRow] = try await client
                .from("pantry")
                .select("id,product_id,quantity,product:product_id(id,name,product_category_id,unit)")
                .eq("user_id", value: uid)
                .order("id", ascending: true)
                .limit(500)
                .execute()
                .value
            self.pantryItems = rows
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteItem(_ item: PantryItemRow) async {
        do {
            _ = try await client
                .from("pantry")
                .delete()
                .eq("id", value: item.id)
                .eq("user_id", value: userId ?? "")
                .execute()
            await refresh()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func deleteItems(with ids: Set<UUID>) async {
        guard !ids.isEmpty else { return }
        do {
            for id in ids {
                _ = try await client
                    .from("pantry")
                    .delete()
                    .eq("id", value: id)
                    .eq("user_id", value: userId ?? "")
                    .execute()
            }
            await refresh()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
