import AppKit
import CoreGraphics

@MainActor
final class SessionState {
    private var systemAsleep = false
    private var screensAsleep = false
    private var observers: [any NSObjectProtocol] = []

    init() {
        observe(NSWorkspace.willSleepNotification) { $0.systemAsleep = true }
        observe(NSWorkspace.didWakeNotification) { $0.systemAsleep = false }
        observe(NSWorkspace.screensDidSleepNotification) { $0.screensAsleep = true }
        observe(NSWorkspace.screensDidWakeNotification) { $0.screensAsleep = false }
    }

    private func observe(_ name: Notification.Name, _ update: @escaping @MainActor (SessionState) -> Void) {
        let token = NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { update(self) }
            }
        }
        observers.append(token)
    }

    isolated deinit {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    var isInhibited: Bool {
        systemAsleep || screensAsleep || sessionInhibited
    }

    private var sessionInhibited: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        let onConsole = session["kCGSessionOnConsoleKey"] as? Bool ?? true
        let locked = session["CGSSessionScreenIsLocked"] as? Bool ?? false
        return !onConsole || locked
    }
}
