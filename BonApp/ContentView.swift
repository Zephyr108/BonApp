import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable { case recipes, pantry, shopping, account }
    @State private var selectedTab: Tab = .recipes
    @EnvironmentObject var auth: AuthViewModel

    // Consider the user logged-in as soon as auth says so (profile row may load later)
    private var isLoggedInStable: Bool { auth.isAuthenticated }

    // Avoid flicker: until we refresh auth once, show placeholders instead of logged-out UI
    @State private var bootstrapped = false

    private var currentUser: AppUser? { auth.currentUser }

    var body: some View {
        TabView(selection: $selectedTab) {
            // 1) Recipes — always visible
            RecipeListView()
                .tabItem { Label("Przepisy", systemImage: "book") }
                .tag(Tab.recipes)

            // 2) Pantry — tab is always present; content depends on auth
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

            // 3) Shopping — tab is always present; content depends on auth
            Group {
                if isLoggedInStable {
                    if let ownerId = currentUser?.id { // only pass a valid UUID string
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

            // 4) Account — always visible
            NavigationStack {
                accountContent
                    .navigationTitle("Konto")
            }
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
            // Zalogowany: od razu pokaż ekran profilu
            ProfileSetupView()
        } else {
            ZStack {
                Color("background").ignoresSafeArea()
                if !bootstrapped {
                    ProgressView()
                } else {
                    VStack(spacing: 16) {
                        NavigationLink(destination: LoginView()) {
                            Text("Zaloguj")
                                .foregroundColor(Color("buttonText"))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Color("login"))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                        NavigationLink(destination: RegistrationView()) {
                            Text("Rejestracja")
                                .foregroundColor(Color("buttonText"))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Color("register"))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                    }
                }
                }
            }
        }
    }

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthViewModel())
    }
}
