import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthViewModel

    private var currentUser: AppUser? { auth.currentUser }

    var body: some View {
        TabView {
            RecipeListView()
                .tabItem { Label("Przepisy", systemImage: "book") }

            if let user = currentUser {
                PantryView()
                    .tabItem { Label("Spiżarnia", systemImage: "tray.fill") }

                ShoppingListView(ownerId: user.id)
                    .tabItem { Label("Zakupy", systemImage: "cart.fill") }
            } else {
                EmptyView().tabItem { Label("Spiżarnia", systemImage: "tray.fill") }
                EmptyView().tabItem { Label("Zakupy", systemImage: "cart.fill") }
            }

            NavigationStack {
                accountContent
                    .navigationTitle("Konto")
            }
            .background(Color("background").ignoresSafeArea())
            .tabItem { Label("Konto", systemImage: "person.crop.circle") }
        }
        .background(Color("background").ignoresSafeArea())
    }

    @ViewBuilder
    private var accountContent: some View {
        if let user = currentUser {
            ZStack {
                Color("background").ignoresSafeArea()
                VStack(spacing: 12) {
                    Text("Zalogowano jako \(user.email)")
                        .foregroundColor(Color("textPrimary"))
                    Button("Wyloguj") {
                        Task { await auth.signOut() }
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
