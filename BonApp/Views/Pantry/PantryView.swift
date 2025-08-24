import SwiftUI
import Supabase

// MARK: - DTO from Supabase
struct PantryItemRow: Identifiable, Decodable, Hashable {
    let id: UUID
    let name: String
    let quantity: String
    let category: String?
}

// MARK: - ViewModel
final class PantryScreenViewModel: ObservableObject {
    @Published var pantryItems: [PantryItemRow] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    private let client = SupabaseManager.shared.client

    @MainActor
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let rows: [PantryItemRow] = try await client.database
                .from("pantry")
                .select("id,name,quantity,category")
                .order("name", ascending: true)
                .execute()
                .value
            self.pantryItems = rows
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteItem(_ item: PantryItemRow) async {
        do {
            _ = try await client.database
                .from("pantry")
                .delete()
                .eq("id", value: item.id)
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
            _ = try await client.database
                .from("pantry")
                .delete()
                .in("id", values: Array(ids))
                .execute()
            await refresh()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}

// MARK: - View
struct PantryView: View {
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
                                    Text(item.name)
                                        .font(.headline)
                                        .foregroundColor(Color("textPrimary"))
                                    Text(item.quantity)
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
            .task { await viewModel.refresh() }
            .onChange(of: isShowingAdd) { new in
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
