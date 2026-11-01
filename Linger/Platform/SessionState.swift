import AppKit
import CoreGraphics

@MainActor
final class SessionState {
    private var systemAsleep = false
    private var screensAsleep = false
    private var screenLockedByNotification = false
    private var observers: [any NSObjectProtocol] = []
    private var distributedObservers: [any NSObjectProtocol] = []

    init() {
        observe(NSWorkspace.willSleepNotification) { $0.systemAsleep = true }
        observe(NSWorkspace.didWakeNotification) { $0.systemAsleep = false }
        observe(NSWorkspace.screensDidSleepNotification) { $0.screensAsleep = true }
        observe(NSWorkspace.screensDidWakeNotification) { $0.screensAsleep = false }
        observeDistributed(Self.screenLockedName) { $0.screenLockedByNotification = true }
        observeDistributed(Self.screenUnlockedName) { $0.screenLockedByNotification = false }
    }

    private func observeDistributed(_ name: Notification.Name, _ update: @escaping @MainActor (SessionState) -> Void) {
        let token = DistributedNotificationCenter.default().addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { update(self) }
            }
        }
        distributedObservers.append(token)
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
        for observer in distributedObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    var isInhibited: Bool {
        Self.isInhibited(
            sessionDictionary: CGSessionCopyCurrentDictionary() as? [String: Any] ?? [:],
            screenLockedByNotification: screenLockedByNotification,
            asleep: systemAsleep || screensAsleep
        )
    }

    // Swift does not import the CFSTR macros in CGSession.h, so the keys are spelled out.
    private nonisolated static let onConsoleKey = "kCGSSessionOnConsoleKey"
    private nonisolated static let screenIsLockedKey = "CGSSessionScreenIsLocked"

    private nonisolated static let screenLockedName = Notification.Name("com.apple.screenIsLocked")
    private nonisolated static let screenUnlockedName = Notification.Name("com.apple.screenIsUnlocked")

    nonisolated static func isInhibited(
        sessionDictionary: [String: Any],
        screenLockedByNotification: Bool,
        asleep: Bool
    ) -> Bool {
        asleep || screenLockedByNotification || isInhibited(sessionDictionary: sessionDictionary)
    }

    nonisolated static func isInhibited(sessionDictionary: [String: Any]) -> Bool {
        let onConsole = sessionDictionary[onConsoleKey] as? Bool ?? false
        let locked = sessionDictionary[screenIsLockedKey] as? Bool ?? false
        return !onConsole || locked
    }
}
