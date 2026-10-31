import CoreGraphics

enum EventPoster {
    static func postZeroDistanceMove() -> Bool {
        guard let location = CGEvent(source: nil)?.location else { return false }
        return postMove(at: location)
    }

    static func postMove(at location: CGPoint) -> Bool {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: location,
            mouseButton: .left
        ) else { return false }
        event.post(tap: .cghidEventTap)
        return true
    }
}
