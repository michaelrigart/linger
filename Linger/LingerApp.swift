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
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Linger", systemImage: "circle") {
            Text("Status: \(String(describing: model.output.status))")
            Text("shouldPost: \(String(model.output.shouldPost))")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
