import SwiftUI
import CoreData

struct LaunchScreenView: View {
    @State private var isActive = false
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        Group {
            if isActive {
                ContentView()
            } else {
                VStack {
                    Image("AppLogoBlack")
                        .resizable()
                        .scaledToFit()
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isActive = true
                }
            }
        }
    }
}

struct LaunchScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreenView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
