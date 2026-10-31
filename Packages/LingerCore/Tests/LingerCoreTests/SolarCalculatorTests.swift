import Foundation
import Testing
@testable import LingerCore

@Test func altitudeMatchesNOAA() {
    #expect(abs(SolarCalculator.altitude(at: utc("2026-10-28T06:19:16Z"), coordinates: brussels) - (-2.038)) < 0.05)
    #expect(abs(SolarCalculator.altitude(at: utc("2026-06-21T11:40:00Z"), coordinates: brussels) - 62.575) < 0.05)
    #expect(abs(SolarCalculator.altitude(at: utc("2026-12-21T23:00:00Z"), coordinates: brussels) - (-61.464)) < 0.1)
}

@Test func crossingsMatchNOAA() {
    expectNear(SolarCalculator.nextCrossing(of: -5, rising: false, after: utc("2026-10-30T11:00:00Z"), coordinates: brussels), utc("2026-10-30T16:48:50Z"))
    expectNear(SolarCalculator.nextCrossing(of: -1, rising: true, after: utc("2026-10-30T20:00:00Z"), coordinates: brussels), utc("2026-10-31T06:31:30Z"))
    expectNear(SolarCalculator.nextCrossing(of: -1, rising: true, after: utc("2026-06-20T22:00:00Z"), coordinates: brussels), utc("2026-06-21T03:27:30Z"))
    expectNear(SolarCalculator.nextCrossing(of: -5, rising: false, after: utc("2026-06-21T12:00:00Z"), coordinates: brussels), utc("2026-06-21T20:36:50Z"))
}

@Test func polarDaysNeverCrossBothThresholds() {
    let tromso = SolarCalculator.altitudeRange(onDayContaining: utc("2026-12-21T12:00:00Z"), timeZone: TimeZone(identifier: "Europe/Oslo")!, coordinates: Coordinates(latitude: 69.65, longitude: 18.96))
    #expect(abs(tromso.upperBound - (-3.09)) < 0.1)
    let longyearbyen = SolarCalculator.altitudeRange(onDayContaining: utc("2026-06-21T12:00:00Z"), timeZone: TimeZone(identifier: "Arctic/Longyearbyen")!, coordinates: Coordinates(latitude: 78.22, longitude: 15.65))
    #expect(abs(longyearbyen.lowerBound - 11.66) < 0.1)
}
