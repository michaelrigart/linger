import AppKit
import ApplicationServices
import CoreGraphics

enum PostAccess {
    static var isGranted: Bool { AXIsProcessTrusted() }

    static func request() {
        _ = CGRequestPostEventAccess()
        guard !isGranted else { return }
        NSWorkspace.shared.open(accessibilitySettings)
    }

    private static let accessibilitySettings = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
}
