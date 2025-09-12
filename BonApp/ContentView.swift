import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable { case recipes, pantry, shopping, account }
    @State private var selectedTab: Tab = .recipes
    @EnvironmentObject var auth: AuthViewModel

    private var currentUser: AppUser? { auth.currentUser }

    var body: some View {
        TabView(selection: $selectedTab) {
            RecipeListView()
                .tabItem { Label("Przepisy", systemImage: "book") }
                .tag(Tab.recipes)

            if auth.isAuthenticated {
                if let user = currentUser {
                    PantryView()
                        .tabItem { Label("Spiżarnia", systemImage: "tray.fill") }
                        .tag(Tab.pantry)

                    ShoppingListView(ownerId: user.id)
                        .tabItem { Label("Zakupy", systemImage: "cart.fill") }
                        .tag(Tab.shopping)
                } else {
                    ProgressView().tabItem { Label("Spiżarnia", systemImage: "tray.fill") }.tag(Tab.pantry)
                    ProgressView().tabItem { Label("Zakupy", systemImage: "cart.fill") }.tag(Tab.shopping)
                }
            } else {
                EmptyView().tabItem { Label("Spiżarnia", systemImage: "tray.fill") }.tag(Tab.pantry)
                EmptyView().tabItem { Label("Zakupy", systemImage: "cart.fill") }.tag(Tab.shopping)
            }

            NavigationStack {
                accountContent
                    .navigationTitle("Konto")
            }
            .background(Color("background").ignoresSafeArea())
            .tabItem { Label("Konto", systemImage: "person.crop.circle") }
            .tag(Tab.account)
        }
        .background(Color("background").ignoresSafeArea())
        .onChange(of: auth.isAuthenticated) { isAuth in
            if isAuth { selectedTab = .recipes }
        }
    }

    @ViewBuilder
    private var accountContent: some View {
        if auth.isAuthenticated {
            ZStack {
                Color("background").ignoresSafeArea()
                VStack(spacing: 12) {
                    if let user = currentUser {
                        Text("Zalogowano jako \(user.email)")
                            .foregroundColor(Color("textPrimary"))
                    } else {
                        Text("Zalogowano")
                            .foregroundColor(Color("textPrimary"))
                    }
                    Button("Wyloguj") {
                        Task { await auth.logout() }
                    }
                    .foregroundColor(Color("buttonText"))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color("register"))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
        } else {
            ZStack {
                Color("background").ignoresSafeArea()
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthViewModel())
    }
}
