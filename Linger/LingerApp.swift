import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        Probe.startIfRequested()
        #endif
    }
}

@main
struct LingerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Linger", systemImage: "circle") {
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
