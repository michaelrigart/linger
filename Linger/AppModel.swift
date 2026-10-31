import AppKit
import Foundation
import LingerCore
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var output = EngineOutput(status: .off, shouldPost: false)
    private(set) var nextStepAside: (target: Appearance, at: Date)?
    private(set) var coordinates: Coordinates?
    private(set) var appearanceIsAuto = false
    private(set) var effectiveAppearance: Appearance = .light

    var settings: LingerSettings {
        didSet { store.save(settings) }
    }

    @ObservationIgnored private let store = SettingsStore()
    @ObservationIgnored private let session = SessionState()
    @ObservationIgnored private var engine = ActivityEngine()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastLoggedStatus: EngineStatus?
    @ObservationIgnored private var probeActive = false
    @ObservationIgnored private var activity: NSObjectProtocol?
    @ObservationIgnored private var lastPostUptime: TimeInterval?
    @ObservationIgnored private var noEffectLogged = false

    init() {
        settings = store.load()
        if !store.hasStoredIsOn {
            store.save(settings)
        }
        #if !DEBUG
        if !store.loginItemConfigured {
            if LoginItem.isEnabled {
                store.loginItemConfigured = true
            } else {
                do {
                    try LoginItem.setEnabled(true)
                    store.loginItemConfigured = true
                    Log.engine.notice("login item enabled on first launch")
                } catch {
                    Log.engine.error("login item failed: \(error.localizedDescription, privacy: .private)")
                }
            }
        }
        #endif

        #if DEBUG
        if UserDefaults.standard.bool(forKey: "LingerProbe") {
            probeActive = true
            return
        }
        #endif

        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Keeping you active"
        )

        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Task { @MainActor [weak self] in self?.tick() }
    }

    isolated deinit {
        timer?.invalidate()
    }

    func setOn(_ on: Bool) {
        settings.isOn = on
        if on { settings.pausedUntil = nil }
        tick()
    }

    func pause(_ d: PauseDuration) {
        settings.pausedUntil = d.end(from: Date(), calendar: .current)
        tick()
    }

    func resume() {
        settings.pausedUntil = nil
        tick()
    }

    func markLoginItemConfigured() {
        store.loginItemConfigured = true
    }

    func refresh() {
        tick()
    }

    func requestAccess() {
        PostAccess.request()
    }

    private func tick() {
        guard !probeActive else { return }
        let now = Date()
        let uptime = ProcessInfo.processInfo.systemUptime
        let idle = IdleSource.seconds()
        let timeZone = TimeZone.current
        let coordinates = TimeZoneCoordinates.coordinates(forIdentifier: timeZone.identifier)
        let isAuto = AppearanceSource.isAuto
        let effective = AppearanceSource.effective

        let input = EngineInput(
            now: now,
            uptime: uptime,
            idle: idle,
            hasPostAccess: PostAccess.isGranted,
            isInhibited: session.isInhibited,
            appearanceIsAuto: isAuto,
            effectiveAppearance: effective,
            coordinates: coordinates,
            timeZone: timeZone
        )
        checkLastPostTookEffect(idle: idle, uptime: uptime)
        let result = engine.tick(input, settings: settings)

        if result.shouldPost {
            let posted = engine.postIfStillAway(
                idleDelay: settings.idleDelay,
                reread: { (IdleSource.seconds(), ProcessInfo.processInfo.systemUptime) },
                post: EventPoster.postZeroDistanceMove
            )
            if posted {
                lastPostUptime = ProcessInfo.processInfo.systemUptime
                Log.engine.notice("posted")
            } else {
                Log.engine.notice("post skipped or failed")
            }
        }

        let next = coordinates.flatMap {
            SwitchSchedule.nextStepAside(after: now, coordinates: $0, timeZone: timeZone, effective: effective)
        }
        if self.coordinates != coordinates { self.coordinates = coordinates }
        if appearanceIsAuto != isAuto { appearanceIsAuto = isAuto }
        if effectiveAppearance != effective { effectiveAppearance = effective }
        if nextStepAside?.target != next?.target || nextStepAside?.at != next?.at { nextStepAside = next }
        if output != result { output = result }
        logStatusChange(result.status)
    }

    private func checkLastPostTookEffect(idle: TimeInterval, uptime: TimeInterval) {
        guard let lastPostUptime else { return }
        if idle > (uptime - lastPostUptime) + 1 {
            guard !noEffectLogged else { return }
            noEffectLogged = true
            Log.engine.error("post had no effect: idle \(idle, privacy: .public)s, last post \(uptime - lastPostUptime, privacy: .public)s ago")
        } else {
            noEffectLogged = false
        }
    }

    private func logStatusChange(_ status: EngineStatus) {
        let previous = lastLoggedStatus
        guard previous != status else { return }
        lastLoggedStatus = status
        Log.engine.notice("status: \(String(describing: status), privacy: .public)")
        if case .steppingAside(let target) = status {
            Log.engine.notice("step-aside started, target \(target.rawValue, privacy: .public)")
        } else if case .steppingAside(let target)? = previous {
            let switched = effectiveAppearance == target
            Log.engine.notice("step-aside ended, target \(target.rawValue, privacy: .public), appearance changed \(switched, privacy: .public)")
        }
    }
}
