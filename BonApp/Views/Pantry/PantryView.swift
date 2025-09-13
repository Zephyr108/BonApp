import SwiftUI
import Supabase

// MARK: - DTO from Supabase
struct PantryItemRow: Identifiable, Decodable, Hashable {
    let id: UUID
    let productId: Int
    let productName: String
    let quantity: Double
    let productCategoryId: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case quantity
        case product
    }

    private struct ProductEmbed: Decodable { let id: Int; let name: String; let product_category_id: Int? }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        productId = try c.decode(Int.self, forKey: .productId)
        quantity = try c.decode(Double.self, forKey: .quantity)
        let p = try c.decode(ProductEmbed.self, forKey: .product)
        productName = p.name
        productCategoryId = p.product_category_id
    }
}

// MARK: - ViewModel
final class PantryScreenViewModel: ObservableObject {
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
            guard let uid = userId, !uid.isEmpty else { self.pantryItems = []; return }
            let rows: [PantryItemRow] = try await client
                .from("pantry")
                .select("id,product_id,quantity,product:product_id(id,name,product_category_id)")
                .eq("user_id", value: uid)
                .order("id", ascending: true)
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
            // Batch delete with `in` filter
            _ = try await client
                .from("pantry")
                .delete()
                .in("id", values: Array(ids))
                .eq("user_id", value: userId ?? "")
                .execute()
            await refresh()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}

// MARK: - View
struct PantryView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var viewModel = PantryScreenViewModel()
    @State private var isShowingAdd = false
    @State private var selectedIds: Set<UUID> = []
    @State private var isSelecting = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color("background").ignoresSafeArea()

                List {
                    if viewModel.isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else if let error = viewModel.error {
                        Text("Błąd: \(error)")
                            .foregroundColor(.secondary)
                            .padding()
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else if viewModel.pantryItems.isEmpty {
                        Text("Brak produktów w spiżarni.")
                            .foregroundColor(Color("textSecondary"))
                            .padding()
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(viewModel.pantryItems) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.productName)
                                        .font(.headline)
                                        .foregroundColor(Color("textPrimary"))
                                    Text(String(format: "%.2f", item.quantity))
                                        .font(.subheadline)
                                        .foregroundColor(Color("textSecondary"))
                                }
                                Spacer()
                            }
                            .padding()
                            .background(rowBackground(for: item.id))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color("textfieldBorder"), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isSelecting {
                                    toggleSelection(for: item.id)
                                }
                            }
                            .onLongPressGesture {
                                isSelecting = true
                                selectedIds.insert(item.id)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteItem(item) }
                                } label: {
                                    Label("Usuń", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color("background"))
            }
            .task {
                viewModel.setUserId(auth.currentUser?.id)
                await viewModel.refresh()
            }
            .onChange(of: auth.currentUser?.id, initial: false) { old, new in
                viewModel.setUserId(new)
                Task { await viewModel.refresh() }
            }
            .onChange(of: isShowingAdd, initial: false) { old, new in
                if new == false { Task { await viewModel.refresh() } }
            }
            .navigationTitle("Spiżarnia")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isShowingAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    if isSelecting {
                        Button(action: {
                            Task {
                                await viewModel.deleteItems(with: selectedIds)
                                await MainActor.run {
                                    selectedIds.removeAll(); isSelecting = false
                                }
                            }
                        }) {
                            Text("Usuń zaznaczone")
                                .foregroundColor(Color("buttonText"))
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color("edit"))
                                .cornerRadius(8)
                        }

                        Spacer()

                        Button(action: {
                            selectedIds.removeAll()
                            isSelecting = false
                        }) {
                            Text("Anuluj")
                                .foregroundColor(Color("buttonText"))
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color("cancel"))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingAdd) {
                AddPantryItemView()
            }
        }
    }

    private func toggleSelection(for id: UUID) {
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
    }

    private func rowBackground(for id: UUID) -> Color {
        selectedIds.contains(id) && isSelecting ? Color("itemsListBackground").opacity(0.6) : Color("itemsListBackground")
    }
}

struct PantryView_Previews: PreviewProvider {
    static var previews: some View {
        PantryView()
    }
}
