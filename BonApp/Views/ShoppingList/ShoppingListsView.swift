import SwiftUI

// MARK: - List of shopping lists (parent screen)
struct ShoppingListsView: View {
    @StateObject private var listsVM: ShoppingListsViewModel
    @State private var isPresentingNewListSheet = false
    @State private var newListName: String = ""
    private let ownerId: String?

    init(ownerId: String?) {
        self.ownerId = ownerId
        _listsVM = StateObject(wrappedValue: ShoppingListsViewModel(ownerId: ownerId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("background").ignoresSafeArea()

                Group {
                    if listsVM.isLoading && listsVM.lists.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if listsVM.lists.isEmpty {
                        ContentUnavailableView("Brak list zakupowych", systemImage: "cart", description: Text("Dodaj nową listę przyciskiem plus."))
                    } else {
                        List {
                            ForEach(listsVM.lists, id: \.id) { list in
                                NavigationLink {
                                    ShoppingListDetailView(
                                        ownerId: ownerId ?? "",
                                        shoppingListId: list.id,
                                        listName: list.name
                                    )
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(list.name)
                                            .font(.headline)
                                            .foregroundColor(Color("textPrimary"))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)

                                        Text("Otwórz listę")
                                            .font(.caption)
                                            .foregroundColor(Color("textSecondary"))
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color("itemsListBackground"))
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task {
                                            await listsVM.deleteList(id: list.id)
                                        }
                                    } label: {
                                        Label("Usuń", systemImage: "trash")
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }

                    if let err = listsVM.error {
                        Text(err)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.top, 8)
                    }
                }
                .navigationTitle("Moje listy zakupów")
                .task { await listsVM.fetchLists() }
                //.onAppear { print("Loaded lists count: \(listsVM.lists.count)") }
                .refreshable { await listsVM.fetchLists() }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            newListName = ""
                            isPresentingNewListSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $isPresentingNewListSheet) {
                    NavigationStack {
                        VStack(spacing: 20) {
                            Text("Nowa lista zakupów")
                                .font(.title2.bold())
                                .padding(.top, 20)

                            TextField("Nazwa listy", text: $newListName)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)

                            Spacer()
                        }
                        .background(Color("background").ignoresSafeArea())
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Anuluj") {
                                    isPresentingNewListSheet = false
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Utwórz") {
                                    let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !name.isEmpty else { return }
                                    Task {
                                        await listsVM.createList(name: name)
                                        await MainActor.run {
                                            isPresentingNewListSheet = false
                                        }
                                    }
                                }
                                .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ShoppingListsView_Previews: PreviewProvider {
    static var previews: some View {
        ShoppingListsView(ownerId: "00000000-0000-0000-0000-000000000000")
    }
}
