#if DEBUG
import CoreGraphics
import Foundation
import LingerCore

@MainActor
enum Probe {
    private static var task: Task<Void, Never>?

    static func startIfRequested() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "LingerProbe") else { return }

        let interval = defaults.object(forKey: "LingerProbeInterval") == nil ? 60 : defaults.double(forKey: "LingerProbeInterval")
        let delay = defaults.double(forKey: "LingerProbeDelay")
        let seconds = defaults.double(forKey: "LingerProbeSeconds")

        let log = Log.probe
        log.info("access granted: \(PostAccess.isGranted, privacy: .public)")
        log.info("idle: \(IdleSource.seconds(), privacy: .public)")
        log.info("isAuto: \(AppearanceSource.isAuto, privacy: .public)")
        log.info("effective: \(AppearanceSource.effective.rawValue, privacy: .public)")
        log.info("inhibited: \(SessionState().isInhibited, privacy: .public)")

        task = Task {
            let start = Date()
            while !Task.isCancelled {
                log.info("idle before: \(IdleSource.seconds(), privacy: .public)")
                if PostAccess.isGranted {
                    let location = CGEvent(source: nil)?.location
                    if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
                    if let location {
                        let posted = EventPoster.postMove(at: location)
                        log.info("posted at \(location.x, privacy: .public),\(location.y, privacy: .public): \(posted, privacy: .public)")
                    }
                } else {
                    log.info("post skipped: no access")
                }
                try? await Task.sleep(for: .milliseconds(500))
                log.info("idle after: \(IdleSource.seconds(), privacy: .public)")

                let remaining = max(interval - 0.5, 0)
                if seconds > 0, Date().timeIntervalSince(start) + remaining >= seconds {
                    let wait = max(seconds - Date().timeIntervalSince(start), 0)
                    try? await Task.sleep(for: .seconds(wait))
                    log.info("probe finished")
                    exit(0)
                }
                try? await Task.sleep(for: .seconds(remaining))
            }
        }
    }
}
#endif
