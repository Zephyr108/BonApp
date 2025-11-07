import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable { case recipes, pantry, shopping, account }
    @State private var selectedTab: Tab = .recipes
    @EnvironmentObject var auth: AuthViewModel
    
    private var isLoggedInStable: Bool { auth.isAuthenticated }
    
    @State private var bootstrapped = false
    
    private var currentUser: AppUser? { auth.currentUser }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RecipeListView()
                .tabItem { Label("Przepisy", systemImage: "book") }
                .tag(Tab.recipes)
            
            Group {
                if isLoggedInStable {
                    PantryView()
                } else if !bootstrapped {
                    ProgressView()
                } else {
                    EmptyView()
                }
            }
            .tabItem { Label("Spiżarnia", systemImage: "tray.fill") }
            .tag(Tab.pantry)
            
            Group {
                if isLoggedInStable {
                    if let ownerId = currentUser?.id {
                        ShoppingListsView(ownerId: ownerId)
                    } else if !bootstrapped {
                        ProgressView()
                    } else {
                        ContentUnavailableView("Brak profilu", systemImage: "person.fill.questionmark", description: Text("Zaloguj się ponownie lub odśwież profil."))
                    }
                } else if !bootstrapped {
                    ProgressView()
                } else {
                    EmptyView()
                }
            }
            .tabItem { Label("Zakupy", systemImage: "cart.fill") }
            .tag(Tab.shopping)
            
            NavigationStack {
                accountContent
                    .navigationTitle("Konto")
            }
            .id(auth.isAuthenticated)
            .background(Color("background").ignoresSafeArea())
            .tabItem { Label("Konto", systemImage: "person.crop.circle") }
            .tag(Tab.account)
        }
        .background(Color("background").ignoresSafeArea())
        .task {
            if !bootstrapped {
                await auth.refreshAuthState()
                bootstrapped = true
            }
        }
        .onChange(of: auth.isAuthenticated, initial: false) { _, isAuth in
            if isAuth { selectedTab = .recipes }
        }
        .onChange(of: auth.currentUser, initial: false) { _, user in
            if user != nil { selectedTab = .recipes }
        }
    }
    
    @ViewBuilder
    private var accountContent: some View {
        if isLoggedInStable {
            AccountHomeView()
                .onAppear {
                    if !auth.isAuthenticated {
                        selectedTab = .recipes
                    }
                }
        } else {
            AuthStartView()
        }
    }
    
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
                .environmentObject(AuthViewModel())
        }
    }
}
