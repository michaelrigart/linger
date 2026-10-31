import Foundation
import Testing
@testable import LingerCore

@Test func dueOnlyBeyondThresholds() {
    #expect(SwitchSchedule.dueSwitch(at: utc("2026-10-28T06:19:16Z"), coordinates: brussels, timeZone: tz, effective: .dark) == nil)
    #expect(SwitchSchedule.dueSwitch(at: utc("2026-10-30T16:50:00Z"), coordinates: brussels, timeZone: tz, effective: .light) == .dark)
    #expect(SwitchSchedule.dueSwitch(at: utc("2026-10-30T16:50:00Z"), coordinates: brussels, timeZone: tz, effective: .dark) == nil)
    #expect(SwitchSchedule.dueSwitch(at: utc("2026-10-31T06:33:00Z"), coordinates: brussels, timeZone: tz, effective: .dark) == .light)
}

@Test func nextStepAsideTimes() {
    let evening = SwitchSchedule.nextStepAside(after: utc("2026-10-30T11:00:00Z"), coordinates: brussels, timeZone: tz, effective: .light)
    #expect(evening?.target == .dark); expectNear(evening?.at, utc("2026-10-30T16:48:50Z"))
    let morning = SwitchSchedule.nextStepAside(after: utc("2026-10-30T19:00:00Z"), coordinates: brussels, timeZone: tz, effective: .dark)
    #expect(morning?.target == .light); expectNear(morning?.at, utc("2026-10-31T06:31:30Z"))
}

@Test func nextStepAsideWhenAlreadyDue() {
    let due = utc("2026-10-30T16:50:00Z")
    let next = SwitchSchedule.nextStepAside(after: due, coordinates: brussels, timeZone: tz, effective: .light)
    #expect(next?.target == .dark)
    #expect(next?.at == due)
}

@Test func dstDayMorning() {
    let m = SwitchSchedule.nextStepAside(after: utc("2027-03-27T23:30:00Z"), coordinates: brussels, timeZone: tz, effective: .dark)
    expectNear(m?.at, utc("2027-03-28T05:27:10Z"))
}

@Test func polarDaysNeverDue() {
    let tromso = Coordinates(latitude: 69.65, longitude: 18.96)
    #expect(SwitchSchedule.dueSwitch(at: utc("2026-12-21T20:00:00Z"), coordinates: tromso, timeZone: TimeZone(identifier: "Europe/Oslo")!, effective: .light) == nil)
    let svalbard = Coordinates(latitude: 78.22, longitude: 15.65)
    #expect(SwitchSchedule.dueSwitch(at: utc("2026-06-21T12:00:00Z"), coordinates: svalbard, timeZone: TimeZone(identifier: "Arctic/Longyearbyen")!, effective: .dark) == nil)
}
