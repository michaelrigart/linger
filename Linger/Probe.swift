#if DEBUG
import CoreGraphics
import Foundation
import LingerCore

@MainActor
enum Probe {
    private static var task: Task<Void, Never>?
    private static var session: SessionState?

    static func startIfRequested() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "LingerProbe") else { return }

        let interval = defaults.object(forKey: "LingerProbeInterval") == nil ? 60 : defaults.double(forKey: "LingerProbeInterval")
        let delay = defaults.double(forKey: "LingerProbeDelay")
        let seconds = defaults.double(forKey: "LingerProbeSeconds")

        let log = Log.probe
        let session = SessionState()
        self.session = session
        log.notice("access granted: \(PostAccess.isGranted, privacy: .public)")
        log.notice("idle: \(IdleSource.seconds(), privacy: .public)")
        log.notice("isAuto: \(AppearanceSource.isAuto, privacy: .public)")
        log.notice("effective: \(AppearanceSource.effective.rawValue, privacy: .public)")
        log.notice("inhibited: \(session.isInhibited, privacy: .public)")

        task = Task {
            let start = Date()
            while !Task.isCancelled {
                log.notice("idle before: \(IdleSource.seconds(), privacy: .public)")
                if PostAccess.isGranted {
                    let location = CGEvent(source: nil)?.location
                    if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
                    if session.isInhibited {
                        log.notice("post skipped: session inhibited")
                    } else if let location {
                        let posted = EventPoster.postMove(at: location)
                        log.notice("posted at \(location.x, privacy: .public),\(location.y, privacy: .public): \(posted, privacy: .public)")
                    }
                } else {
                    log.notice("post skipped: no access")
                }
                try? await Task.sleep(for: .milliseconds(500))
                log.notice("idle after: \(IdleSource.seconds(), privacy: .public)")

                let remaining = max(interval - 0.5, 0)
                if seconds > 0, Date().timeIntervalSince(start) + remaining >= seconds {
                    let wait = max(seconds - Date().timeIntervalSince(start), 0)
                    try? await Task.sleep(for: .seconds(wait))
                    log.notice("probe finished")
                    exit(0)
                }
                try? await Task.sleep(for: .seconds(remaining))
            }
        }
    }
}
#endif
