import SwiftUI
import CoreData

struct PantryView: View {
    @ObservedObject var user: User
    @StateObject private var viewModel: PantryViewModel
    @State private var isShowingAdd = false

    init(user: User) {
        self.user = user
        _viewModel = StateObject(wrappedValue: PantryViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("background").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        if viewModel.pantryItems.isEmpty {
                            Text("Brak produktów w spiżarni.")
                                .foregroundColor(Color("textSecondary"))
                                .padding()
                        } else {
                            ForEach(viewModel.pantryItems, id: \.self) { item in
                                NavigationLink(destination: EditPantryItemView(item: item)) {
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
                                    .background(Color("textfieldBackground"))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color("textfieldBorder"), lineWidth: 1)
                                    )
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        if let index = viewModel.pantryItems.firstIndex(of: item) {
                                            deleteItems(offsets: IndexSet(integer: index))
                                        }
                                    } label: {
                                        Label("Usuń", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Spiżarnia")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isShowingAdd = true }) {
                        Image(systemName: "plus")
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
        let user = User(context: PersistenceController.shared.container.viewContext)
        // Optionally add pantry items to user for preview
        return PantryView(user: user)
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
