import SwiftUI
import CoreData

struct PantryView: View {
    @ObservedObject var user: User
    @StateObject private var viewModel: PantryViewModel
    @State private var isShowingAdd = false
    @State private var selectedItems: Set<PantryItem> = []
    @State private var isSelecting = false

    init(user: User) {
        self.user = user
        _viewModel = StateObject(wrappedValue: PantryViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("background").ignoresSafeArea()
                
                List(selection: $selectedItems) {
                    if viewModel.pantryItems.isEmpty {
                        Text("Brak produktów w spiżarni.")
                            .foregroundColor(Color("textSecondary"))
                            .padding()
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(viewModel.pantryItems, id: \.self) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name ?? "")
                                        .font(.headline)
                                        .foregroundColor(Color("textPrimary"))
                                    Text(item.quantity ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(Color("textSecondary"))
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color("itemsListBackground"))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color("textfieldBorder"), lineWidth: 1)
                            )
                            .onTapGesture {
                                if isSelecting {
                                    if selectedItems.contains(item) {
                                        selectedItems.remove(item)
                                    } else {
                                        selectedItems.insert(item)
                                    }
                                }
                            }
                            .onLongPressGesture {
                                isSelecting = true
                                selectedItems.insert(item)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    if let index = viewModel.pantryItems.firstIndex(of: item) {
                                        deleteItems(offsets: IndexSet(integer: index))
                                    }
                                } label: {
                                    Label("Usuń", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .environment(\.editMode, .constant(isSelecting ? EditMode.active : EditMode.inactive))
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color("background"))
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
                            selectedItems.forEach { viewModel.deleteItem($0) }
                            selectedItems.removeAll()
                            isSelecting = false
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
                            selectedItems.removeAll()
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
                AddPantryItemView { name, quantity, category in
                    viewModel.addItem(name: name, quantity: quantity, category: category, owner: user)
                    isShowingAdd = false
                }
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        offsets.map { viewModel.pantryItems[$0] }.forEach(viewModel.deleteItem)
    }
}

struct PantryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let user = User(context: context)

        let sampleItem = PantryItem(context: context)
        sampleItem.name = "Makaron"
        sampleItem.quantity = "2 opakowania"
        sampleItem.owner = user

        return PantryView(user: user)
            .environment(\.managedObjectContext, context)
    }
}
