import SwiftUI
import Supabase


struct PantryView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var viewModel = PantryViewModel()
    @State private var selectedIds: Set<UUID> = []
    @State private var isSelecting = false
    @State private var categoryNames: [Int: String] = [:]

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

            HStack {
                Text("\(quantityString) \(item.productUnit ?? "")")
                    .font(.subheadline)
                    .foregroundColor(Color("textSecondary"))

                Spacer()

                if let categoryId = item.productCategoryId {
                    let name = categoryNames[categoryId]
                    Text(name ?? "Kategoria")
                        .font(.subheadline)
                        .foregroundColor(Color("textSecondary"))
                        .task(id: name == nil ? categoryId : -1) {
                            if categoryNames[categoryId] == nil {
                                await fetchCategoryName(id: categoryId)
                            }
                        }
                }
            }
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

    @MainActor
    private func setCategoryName(_ id: Int, _ name: String) {
        categoryNames[id] = name
    }

    private func fetchCategoryName(id: Int) async {
        do {
            struct CategoryRow: Decodable { let name: String }
            let row: CategoryRow = try await SupabaseManager.shared.client
                .from("product_category")
                .select("name")
                .eq("id", value: id)
                .single()
                .execute()
                .value
            await MainActor.run { setCategoryName(id, row.name) }
        } catch {
            // optional: keep silent; fallback label will remain generic
        }
    }
}

struct PantryView_Previews: PreviewProvider {
    static var previews: some View {
        PantryView()
    }
}

