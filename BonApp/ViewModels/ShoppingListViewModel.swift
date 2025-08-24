import Foundation
import Supabase

// MARK: - DTOs
struct ShoppingListItemDTO: Identifiable, Hashable, Decodable {
    let id: UUID
    let name: String
    let quantity: String
    let isBought: Bool
    let category: String?
    let ownerId: String

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, category
        case isBought = "is_bought"
        case ownerId = "owner_id"
    }
}

private struct ShoppingInsert: Encodable {
    let name: String
    let quantity: String
    let is_bought: Bool
    let owner_id: String
    let category: String?
}

private struct ShoppingUpdate: Encodable {
    let name: String
    let quantity: String
}

private struct BoughtUpdate: Encodable { let is_bought: Bool }

private struct PantryInsert: Encodable {
    let id: UUID
    let name: String
    let quantity: String
    let category: String?
    let owner_id: String
}

final class ShoppingListViewModel: ObservableObject {
    @Published var items: [ShoppingListItemDTO] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    private let client = SupabaseManager.shared.client
    private let ownerId: String

    // MARK: - Init
    init(ownerId: String) {
        self.ownerId = ownerId
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
            let rows: [ShoppingListItemDTO] = try await client.database
                .from("shopping_list")
                .select("id,name,quantity,is_bought,category,owner_id")
                .eq("owner_id", value: ownerId)
                .order("is_bought", ascending: true)
                .order("name", ascending: true)
                .execute()
                .value
            self.items = rows
        } catch {
            self.error = error.localizedDescription
            self.items = []
        }
    }

    // MARK: - Add
    func addItem(name: String, quantity: String, category: String?) async {
        let payload = ShoppingInsert(name: name, quantity: quantity, is_bought: false, owner_id: ownerId, category: category)
        do {
            _ = try await client.database.from("shopping_list").insert(payload).execute()
            await fetchItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Update
    func updateItem(id: UUID, name: String, quantity: String) async {
        let payload = ShoppingUpdate(name: name, quantity: quantity)
        do {
            _ = try await client.database
                .from("shopping_list")
                .update(payload)
                .eq("id", value: id)
                .eq("owner_id", value: ownerId)
                .execute()
            await fetchItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Delete
    func deleteItem(id: UUID) async {
        do {
            _ = try await client.database
                .from("shopping_list")
                .delete()
                .eq("id", value: id)
                .eq("owner_id", value: ownerId)
                .execute()
            await fetchItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Mark as bought
    func markAsBought(id: UUID) async {
        do {
            _ = try await client.database
                .from("shopping_list")
                .update(BoughtUpdate(is_bought: true))
                .eq("id", value: id)
                .eq("owner_id", value: ownerId)
                .execute()
            await fetchItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Transfer bought items to pantry
    func transferBoughtItemsToPantry() async {
        do {
            // 1) Pobierz kupione pozycje bieżącego użytkownika
            struct Row: Decodable { let id: UUID; let name: String; let quantity: String; let category: String? }
            let rows: [Row] = try await client.database
                .from("shopping_list")
                .select("id,name,quantity,category")
                .eq("owner_id", value: ownerId)
                .eq("is_bought", value: true)
                .execute()
                .value
            guard !rows.isEmpty else { return }

            // 2) Zbuduj payload do tabeli pantry (batch insert)
            let pantryPayload: [PantryInsert] = rows.map { r in
                PantryInsert(id: UUID(), name: r.name, quantity: r.quantity, category: r.category, owner_id: ownerId)
            }
            _ = try await client.database
                .from("pantry")
                .insert(pantryPayload)
                .execute()

            // 3) Usuń kupione pozycje z listy zakupów
            let ids = rows.map { $0.id }
            _ = try await client.database
                .from("shopping_list")
                .delete()
                .in("id", values: ids)
                .eq("owner_id", value: ownerId)
                .execute()

            await fetchItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Refresh
    func refresh() async { await fetchItems() }
}
