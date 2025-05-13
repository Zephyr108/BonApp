import SwiftUI

/// Directions for swipe gestures.
enum SwipeDirection {
    case left, right, up, down
}

/// A utility struct grouping common gesture definitions.
struct GestureHandler {
    
    /// Creates a drag gesture with callbacks.
    /// - Parameters:
    ///   - onChanged: called continuously with the drag translation.
    ///   - onEnded: called when the drag ends, with the final translation.
    /// - Returns: a DragGesture instance.
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

    /// Creates a swipe gesture in the specified direction.
    /// - Parameters:
    ///   - direction: the direction to detect.
    ///   - threshold: minimum translation to consider as a swipe.
    ///   - perform: called when a swipe in the given direction is detected.
    /// - Returns: a Gesture that detects directional swipes.
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

    /// Creates a long-press gesture.
    /// - Parameters:
    ///   - minimumDuration: how long the press must last.
    ///   - perform: called when the long press completes.
    /// - Returns: a LongPressGesture instance.
    static func longPressGesture(
        minimumDuration: Double = 0.5,
        perform: @escaping () -> Void
    ) -> some Gesture {
        LongPressGesture(minimumDuration: minimumDuration)
            .onEnded { _ in perform() }
    }
    
    /// Creates a double-tap gesture.
    /// - Parameter perform: called when the double-tap is recognized.
    /// - Returns: a TapGesture configured for double-taps.
    static func doubleTapGesture(
        perform: @escaping () -> Void
    ) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                perform()
            }
    }
}


    
