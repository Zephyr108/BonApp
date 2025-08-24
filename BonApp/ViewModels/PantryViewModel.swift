import Foundation
import Supabase

struct PantryItemDTO: Identifiable, Hashable, Decodable {
    let id: UUID
    let name: String
    let quantity: String
    let category: String?
    let ownerId: String

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, category
        case ownerId = "owner_id"
    }
}

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
            let rows: [PantryItemDTO] = try await client.database
                .from("pantry")
                .select("id,name,quantity,category,owner_id")
                .eq("owner_id", value: userId)
                .order("category", ascending: true)
                .order("name", ascending: true)
                .execute()
                .value
            self.pantryItems = rows
        } catch {
            self.error = error.localizedDescription
            self.pantryItems = []
        }
    }

    // MARK: - Add
    func addItem(name: String, quantity: String, category: String?) async {
        let payload: [String: AnyJSON] = [
            "name": .string(name),
            "quantity": .string(quantity),
            "category": (category != nil ? .string(category!) : .null),
            "owner_id": .string(userId)
        ]
        do {
            _ = try await client.database.from("pantry").insert(payload).execute()
            await fetchPantryItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Update
    func updateItem(id: UUID, name: String, quantity: String, category: String?) async {
        let payload: [String: AnyJSON] = [
            "name": .string(name),
            "quantity": .string(quantity),
            "category": (category != nil ? .string(category!) : .null)
        ]
        do {
            _ = try await client.database
                .from("pantry")
                .update(payload)
                .eq("id", value: id)
                .eq("owner_id", value: userId)
                .execute()
            await fetchPantryItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Delete
    func deleteItem(id: UUID) async {
        do {
            _ = try await client.database
                .from("pantry")
                .delete()
                .eq("id", value: id)
                .eq("owner_id", value: userId)
                .execute()
            await fetchPantryItems()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func refresh() async { await fetchPantryItems() }
}
