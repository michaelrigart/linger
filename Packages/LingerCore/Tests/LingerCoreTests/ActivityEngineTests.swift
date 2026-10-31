import Foundation
import Testing
@testable import LingerCore

private let midday = utc("2026-10-30T12:00:00Z")
private let dusk = utc("2026-10-30T16:50:00Z")

private func input(
    uptime: TimeInterval,
    idle: TimeInterval,
    now: Date = midday,
    hasPostAccess: Bool = true,
    isInhibited: Bool = false,
    appearanceIsAuto: Bool = true,
    effective: Appearance = .light,
    coordinates: Coordinates? = brussels
) -> EngineInput {
    EngineInput(
        now: now, uptime: uptime, idle: idle, hasPostAccess: hasPostAccess, isInhibited: isInhibited,
        appearanceIsAuto: appearanceIsAuto, effectiveAppearance: effective,
        coordinates: coordinates, timeZone: tz
    )
}

private func isActive(_ status: EngineStatus) -> Bool {
    if case .active = status { true } else { false }
}

@Test func postsOnceIdleReachesDelay() {
    var engine = ActivityEngine()
    let settings = LingerSettings()
    #expect(engine.tick(input(uptime: 1000, idle: 59), settings: settings).shouldPost == false)
    #expect(engine.tick(input(uptime: 1001, idle: 60), settings: settings).shouldPost == true)
}

@Test func repostsEveryMinute() {
    var engine = ActivityEngine()
    let settings = LingerSettings()
    engine.didPost(atUptime: 100)
    #expect(engine.tick(input(uptime: 159, idle: 59), settings: settings).shouldPost == false)
    #expect(engine.tick(input(uptime: 160, idle: 60), settings: settings).shouldPost == true)
}

@Test func ownEventIsNotMistakenForReturn() {
    var engine = ActivityEngine()
    engine.didPost(atUptime: 100)
    #expect(engine.isUserAway(idle: 30.0, uptime: 130, idleDelay: 60))
}

@Test func inputHalfSecondAfterPostIsDetected() {
    var engine = ActivityEngine()
    engine.didPost(atUptime: 100)
    #expect(engine.isUserAway(idle: 9.5, uptime: 110, idleDelay: 60) == false)
    let out = engine.tick(input(uptime: 110, idle: 9.5), settings: LingerSettings())
    #expect(out.shouldPost == false)
    #expect(isActive(out.status))
}

private struct InhibitorCase: CustomTestStringConvertible, Sendable {
    let name: String
    let access: Bool
    let inhibited: Bool
    let settings: LingerSettings
    let check: @Sendable (EngineStatus) -> Bool
    var testDescription: String { name }
}

private let inhibitorCases: [InhibitorCase] = [
    InhibitorCase(name: "no access", access: false, inhibited: false, settings: LingerSettings()) {
        $0 == .needsPermission
    },
    InhibitorCase(name: "off", access: true, inhibited: false, settings: LingerSettings(isOn: false)) {
        $0 == .off
    },
    InhibitorCase(
        name: "paused", access: true, inhibited: false,
        settings: LingerSettings(pausedUntil: midday.addingTimeInterval(600))
    ) {
        if case .paused = $0 { true } else { false }
    },
    InhibitorCase(name: "inhibited", access: true, inhibited: true, settings: LingerSettings()) {
        if case .active = $0 { true } else { false }
    },
    InhibitorCase(name: "no access and off", access: false, inhibited: true, settings: LingerSettings(isOn: false)) {
        $0 == .needsPermission
    },
]

@Test(arguments: inhibitorCases)
private func inhibitorsNeverPost(_ c: InhibitorCase) {
    var engine = ActivityEngine()
    let out = engine.tick(
        input(uptime: 1000, idle: 600, hasPostAccess: c.access, isInhibited: c.inhibited),
        settings: c.settings
    )
    #expect(c.check(out.status))
    #expect(out.shouldPost == false)
}

@Test func stepsAsideAtDusk() {
    var engine = ActivityEngine()
    let out = engine.tick(input(uptime: 1000, idle: 60, now: dusk), settings: LingerSettings())
    #expect(out.status == .steppingAside(target: .dark))
    #expect(out.shouldPost == false)
}

@Test func resumesWhenAppearanceChanges() {
    var engine = ActivityEngine()
    let settings = LingerSettings()
    _ = engine.tick(input(uptime: 1000, idle: 60, now: dusk), settings: settings)
    let out = engine.tick(input(uptime: 1005, idle: 65, now: dusk, effective: .dark), settings: settings)
    #expect(out.shouldPost == true)
    #expect(isActive(out.status))
}

@Test func gapBudgetEndsStepAsideOnce() {
    var engine = ActivityEngine()
    let settings = LingerSettings()
    _ = engine.tick(input(uptime: 1000, idle: 60, now: dusk), settings: settings)
    let before = engine.tick(input(uptime: 1899, idle: 959, now: dusk), settings: settings)
    #expect(before.status == .steppingAside(target: .dark))
    #expect(before.shouldPost == false)
    let ended = engine.tick(input(uptime: 1900, idle: 960, now: dusk), settings: settings)
    #expect(ended.shouldPost == true)
    engine.didPost(atUptime: 1900)
    let after = engine.tick(input(uptime: 1960, idle: 60, now: dusk), settings: settings)
    #expect(isActive(after.status))
    #expect(after.shouldPost == true)
}

@Test func retriesOnNextAbsence() {
    var engine = ActivityEngine()
    let settings = LingerSettings()
    _ = engine.tick(input(uptime: 1000, idle: 60, now: dusk), settings: settings)
    _ = engine.tick(input(uptime: 1900, idle: 960, now: dusk), settings: settings)
    engine.didPost(atUptime: 1900)
    let back = engine.tick(input(uptime: 1950, idle: 5, now: dusk), settings: settings)
    #expect(isActive(back.status))
    #expect(back.shouldPost == false)
    let again = engine.tick(input(uptime: 2000, idle: 60, now: dusk), settings: settings)
    #expect(again.status == .steppingAside(target: .dark))
    #expect(again.shouldPost == false)
}

@Test func leavingAutoMidStepAsideResumes() {
    var engine = ActivityEngine()
    let settings = LingerSettings()
    _ = engine.tick(input(uptime: 1000, idle: 60, now: dusk), settings: settings)
    let out = engine.tick(input(uptime: 1005, idle: 65, now: dusk, appearanceIsAuto: false), settings: settings)
    #expect(out.shouldPost == true)
    #expect(isActive(out.status))
}

@Test func disablingStepAsideMidStepAsideResumes() {
    var engine = ActivityEngine()
    _ = engine.tick(input(uptime: 1000, idle: 60, now: dusk), settings: LingerSettings())
    let out = engine.tick(
        input(uptime: 1005, idle: 65, now: dusk),
        settings: LingerSettings(stepAsideEnabled: false)
    )
    #expect(out.shouldPost == true)
    #expect(isActive(out.status))
}

@Test func noCoordinatesNeverStepsAside() {
    var engine = ActivityEngine()
    let out = engine.tick(input(uptime: 1000, idle: 60, now: dusk, coordinates: nil), settings: LingerSettings())
    #expect(out.shouldPost == true)
    #expect(isActive(out.status))
}

@Test func permissionRevokedAndRegranted() {
    var engine = ActivityEngine()
    let settings = LingerSettings()
    let first = engine.tick(input(uptime: 1000, idle: 60), settings: settings)
    #expect(first.shouldPost == true)
    engine.didPost(atUptime: 1000)
    let revoked = engine.tick(input(uptime: 1005, idle: 65, hasPostAccess: false), settings: settings)
    #expect(revoked.status == .needsPermission)
    #expect(revoked.shouldPost == false)
    let granted = engine.tick(input(uptime: 1010, idle: 600), settings: settings)
    #expect(granted.shouldPost == true)
}

@Test func lockClearsAbsence() {
    var engine = ActivityEngine()
    engine.didPost(atUptime: 100)
    _ = engine.tick(input(uptime: 101, idle: 2.0, isInhibited: true), settings: LingerSettings())
    #expect(engine.isUserAway(idle: 2.0, uptime: 102, idleDelay: 60) == false)
}

@Test func skipsPostWhenUserReturnsBeforePosting() {
    var engine = ActivityEngine()
    engine.didPost(atUptime: 100)
    let out = engine.tick(input(uptime: 160, idle: 60), settings: LingerSettings())
    #expect(out.shouldPost == true)
    var calls = 0
    let posted = engine.postIfStillAway(
        idleDelay: 60,
        reread: { (idle: 0.4, uptime: 160.5) },
        post: { calls += 1; return true }
    )
    #expect(posted == false)
    #expect(calls == 0)
}

@Test func recordsPostOnlyWhenPosterSucceeds() {
    var engine = ActivityEngine()
    let settings = LingerSettings()
    #expect(engine.tick(input(uptime: 1000, idle: 60), settings: settings).shouldPost == true)
    let failed = engine.postIfStillAway(idleDelay: 60, reread: { (idle: 60, uptime: 1000) }, post: { false })
    #expect(failed == false)
    #expect(engine.tick(input(uptime: 1005, idle: 65), settings: settings).shouldPost == true)
    let posted = engine.postIfStillAway(idleDelay: 60, reread: { (idle: 65, uptime: 1005) }, post: { true })
    #expect(posted == true)
    #expect(engine.tick(input(uptime: 1010, idle: 70), settings: settings).shouldPost == false)
}
