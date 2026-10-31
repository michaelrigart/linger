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

    init() {
        settings = store.load()
        if !store.hasStoredIsOn {
            #if !DEBUG
            do {
                try LoginItem.setEnabled(true)
                Log.engine.notice("login item enabled on first launch")
            } catch {
                Log.engine.error("login item failed: \(error.localizedDescription, privacy: .private)")
            }
            #endif
            store.save(settings)
        }

        #if DEBUG
        if UserDefaults.standard.bool(forKey: "LingerProbe") {
            probeActive = true
            return
        }
        #endif

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

    func requestAccess() {
        PostAccess.request()
    }

    private func tick() {
        guard !probeActive else { return }
        let now = Date()
        let timeZone = TimeZone.current
        let coordinates = TimeZoneCoordinates.coordinates(forIdentifier: timeZone.identifier)
        let isAuto = AppearanceSource.isAuto
        let effective = AppearanceSource.effective

        let input = EngineInput(
            now: now,
            uptime: ProcessInfo.processInfo.systemUptime,
            idle: IdleSource.seconds(),
            hasPostAccess: PostAccess.isGranted,
            isInhibited: session.isInhibited,
            appearanceIsAuto: isAuto,
            effectiveAppearance: effective,
            coordinates: coordinates,
            timeZone: timeZone
        )
        let result = engine.tick(input, settings: settings)

        if result.shouldPost {
            let posted = engine.postIfStillAway(
                idleDelay: settings.idleDelay,
                reread: { (IdleSource.seconds(), ProcessInfo.processInfo.systemUptime) },
                post: EventPoster.postZeroDistanceMove
            )
            if posted {
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

    private func logStatusChange(_ status: EngineStatus) {
        let previous = lastLoggedStatus
        guard previous != status else { return }
        lastLoggedStatus = status
        Log.engine.notice("status: \(String(describing: status), privacy: .public)")
        if case .steppingAside(let target) = status {
            Log.engine.notice("step-aside started, target \(target.rawValue, privacy: .public)")
        } else if case .steppingAside(let target)? = previous {
            Log.engine.notice("step-aside ended, target \(target.rawValue, privacy: .public)")
        }
    }
}
