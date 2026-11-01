import AppKit
import CoreGraphics

enum PostAccess {
    static var isGranted: Bool { CGPreflightPostEventAccess() }

    static func request() {
        guard !CGRequestPostEventAccess() else { return }
        NSWorkspace.shared.open(accessibilitySettings)
    }

    private static let accessibilitySettings = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
}
