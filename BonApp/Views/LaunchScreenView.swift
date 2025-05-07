import SwiftUI
import CoreData

struct LaunchScreenView: View {
    @State private var isActive = false
    var preview: Bool = false
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color("background").ignoresSafeArea()
            Group {
                if isActive {
                    ContentView()
                } else {
                    VStack {
                        Image(colorScheme == .dark ? "AppLogoWhite" : "AppLogoBlack")
                            .resizable()
                            .scaledToFit()
                    }
                }
            }
        }
        .onAppear {
            if !preview {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isActive = true
                    }
                }
            }
        }
    }
}

struct LaunchScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreenView(preview: true)
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
