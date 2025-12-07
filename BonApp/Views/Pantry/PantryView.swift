import SwiftUI
import Supabase

// MARK: - DTO from Supabase
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

// MARK: - View
struct PantryView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var viewModel = PantryScreenViewModel()
    @State private var selectedIds: Set<UUID> = []
    @State private var isSelecting = false

    @ViewBuilder
    private func pantryRowView(for item: PantryItemRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.productName)
                .font(.headline)
                .foregroundColor(Color("textPrimary"))
                .frame(maxWidth: .infinity, alignment: .leading)

            let qty = item.quantity
            let quantityString: String = {
                if qty.truncatingRemainder(dividingBy: 1) == 0 {
                    return String(Int(qty))
                } else {
                    return String(format: "%.2f", qty)
                }
            }()

            Text("\(quantityString) \(item.productUnit ?? "")")
                .font(.subheadline)
                .foregroundColor(Color("textSecondary"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func listRow(for item: PantryItemRow) -> some View {
        if isSelecting {
            pantryRowView(for: item)
                .background(rowBackground(for: item.id))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleSelection(for: item.id)
                }
                .onLongPressGesture {
                    isSelecting = true
                    selectedIds.insert(item.id)
                }
        } else {
            NavigationLink(
                destination: EditPantryItemView(
                    itemId: item.id,
                    productName: item.productName,
                    unit: item.productUnit ?? ""
                )
            ) {
                pantryRowView(for: item)
                    .background(rowBackground(for: item.id))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
            }
            .contentShape(Rectangle())
        }
    }

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
                            listRow(for: item)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteItem(item) }
                                    } label: {
                                        Label("Usuń", systemImage: "trash")
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
            .navigationTitle("Spiżarnia")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        AddPantryItemView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelecting {
                    HStack {
                        Button {
                            Task {
                                await viewModel.deleteItems(with: selectedIds)
                                await MainActor.run {
                                    selectedIds.removeAll()
                                    isSelecting = false
                                }
                            }
                        } label: {
                            Text("Usuń zaznaczone")
                                .foregroundColor(Color("buttonText"))
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color("edit"))
                                .cornerRadius(8)
                        }

                        Spacer()

                        Button {
                            selectedIds.removeAll()
                            isSelecting = false
                        } label: {
                            Text("Anuluj")
                                .foregroundColor(Color("buttonText"))
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color("cancel"))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                }
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
