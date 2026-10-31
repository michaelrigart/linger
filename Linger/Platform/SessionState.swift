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
        Self.isInhibited(session: CGSessionCopyCurrentDictionary())
    }

    // Swift does not import the CFSTR macros in CGSession.h, so the keys are spelled out.
    private nonisolated static let onConsoleKey = "kCGSSessionOnConsoleKey"
    private nonisolated static let screenIsLockedKey = "CGSSessionScreenIsLocked"

    nonisolated static func isInhibited(session: CFDictionary?) -> Bool {
        isInhibited(sessionDictionary: session as? [String: Any] ?? [:])
    }

    nonisolated static func isInhibited(sessionDictionary: [String: Any]) -> Bool {
        let onConsole = sessionDictionary[onConsoleKey] as? Bool ?? false
        let locked = sessionDictionary[screenIsLockedKey] as? Bool ?? false
        return !onConsole || locked
    }
}
