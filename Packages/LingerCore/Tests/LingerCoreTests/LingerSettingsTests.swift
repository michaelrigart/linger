import Foundation
import Testing
@testable import LingerCore

@Test func todayEndsAtNextLocalMidnight() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Brussels")!
    #expect(PauseDuration.today.end(from: utc("2026-10-30T14:00:00Z"), calendar: cal) == utc("2026-10-30T23:00:00Z"))
    #expect(PauseDuration.today.end(from: utc("2027-03-28T13:00:00Z"), calendar: cal) == utc("2027-03-28T22:00:00Z"))
}

@Test func fixedPauses() {
    let now = utc("2026-10-30T14:00:00Z")
    #expect(PauseDuration.fifteenMinutes.end(from: now, calendar: .current) == now.addingTimeInterval(900))
    #expect(PauseDuration.oneHour.end(from: now, calendar: .current) == now.addingTimeInterval(3600))
}

@Test func isPausedUntilTheEnd() {
    let end = utc("2026-10-30T15:00:00Z")
    let s = LingerSettings(pausedUntil: end)
    #expect(s.isPaused(at: end.addingTimeInterval(-1)))
    #expect(!s.isPaused(at: end))
}

@Test func defaults() {
    let s = LingerSettings()
    #expect(s.isOn && s.stepAsideEnabled && s.idleDelay == 60 && s.gapBudget == 900 && s.pausedUntil == nil)
}
