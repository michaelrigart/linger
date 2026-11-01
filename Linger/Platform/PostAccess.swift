import AppKit
import ApplicationServices
import CoreGraphics

enum PostAccess {
    static var isGranted: Bool { CGPreflightPostEventAccess() || AXIsProcessTrusted() }

    static func request() {
        guard !CGRequestPostEventAccess() else { return }
        NSWorkspace.shared.open(accessibilitySettings)
    }

    private static let accessibilitySettings = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
}
