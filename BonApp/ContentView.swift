import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var auth = AuthViewModel()

    var body: some View {
        let currentUser = auth.currentUser
        TabView {
            // Recipes tab
            RecipeListView()
                .tabItem { Label("Przepisy", systemImage: "book") }
            
            // Pantry tab: show only if authenticated
            if auth.isAuthenticated, let user = currentUser {
                PantryView(user: user)
                    .tabItem { Label("Spiżarnia", systemImage: "tray.fill") }
                
                ShoppingListView(user: user)
                    .tabItem { Label("Zakupy", systemImage: "cart.fill") }
            } else {
                // place‐holders to keep tab order
                EmptyView().tabItem { Label("Spiżarnia", systemImage: "tray.fill") }
                EmptyView().tabItem { Label("Zakupy", systemImage: "cart.fill") }
            }
            
            // Account tab
            NavigationStack {
                if auth.isAuthenticated, let user = currentUser {
                    ProfileSetupView(user: user)
                } else {
                    VStack(spacing: 16) {
                        NavigationLink(destination: LoginView()) {
                            Text("Zaloguj")
                                .foregroundColor(Color("textPrimary"))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Color("login"))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                        NavigationLink(destination: RegistrationView()) {
                            Text("Rejestracja")
                                .foregroundColor(Color("textPrimary"))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Color("register"))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                    }
                    .background(Color("background").ignoresSafeArea())
                    .navigationTitle("Konto")
                }
            }
            .background(Color("background").ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Always show settings icon; pass currentUser or a new User if nil
                    NavigationLink(destination: SettingsView(user: auth.currentUser ?? User(context: viewContext))) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .tabItem { Label("Konto", systemImage: "person.crop.circle") }
        }
        .environmentObject(auth)
        .background(Color("background").ignoresSafeArea())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        // Create a sample user for preview
        let sampleUser = User(context: context)
        sampleUser.name = "Jan"
        sampleUser.email = "jan@example.com"
        sampleUser.password = "Password1"
        return ContentView()
            .environment(\.managedObjectContext, context)
    }
}
