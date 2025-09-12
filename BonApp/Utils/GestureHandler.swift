import SwiftUI

//kierunki
enum SwipeDirection {
    case left, right, up, down
}

//cała struktura do gestów
struct GestureHandler {
    
    //drag
    static func dragGesture(
        onChanged: @escaping (CGSize) -> Void,
        onEnded: @escaping (CGSize) -> Void
    ) -> some Gesture {
        DragGesture()
            .onChanged { value in
                onChanged(value.translation)
            }
            .onEnded { value in
                onEnded(value.translation)
            }
    }

    //swipe
    static func swipeGesture(
        _ direction: SwipeDirection,
        threshold: CGFloat = 50,
        perform: @escaping () -> Void
    ) -> some Gesture {
        DragGesture()
            .onEnded { value in
                switch direction {
                case .left where value.translation.width < -threshold:
                    perform()
                case .right where value.translation.width > threshold:
                    perform()
                case .up where value.translation.height < -threshold:
                    perform()
                case .down where value.translation.height > threshold:
                    perform()
                default:
                    break
                }
            }
    }

    //long-press
    static func longPressGesture(
        minimumDuration: Double = 0.5,
        perform: @escaping () -> Void
    ) -> some Gesture {
        LongPressGesture(minimumDuration: minimumDuration)
            .onEnded { _ in perform() }
    }
    
    //double-tap
    static func doubleTapGesture(
        user: AppUser?,
        perform: @escaping () -> Void
    ) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                guard user != nil else { return }
                perform()
            }
    }
}


    
