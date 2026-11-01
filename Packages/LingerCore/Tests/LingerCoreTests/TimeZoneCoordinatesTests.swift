import Testing
@testable import LingerCore

@Test func timeZoneCoordinates() {
    expectCoords(TimeZoneCoordinates.coordinates(forIdentifier: "Europe/Brussels"), 50.8333, 4.3333)
    expectCoords(TimeZoneCoordinates.coordinates(forIdentifier: "Europe/Amsterdam"), 52.3667, 4.9)
    expectCoords(TimeZoneCoordinates.coordinates(forIdentifier: "America/Los_Angeles"), 34.0522, -118.2428)
    #expect(TimeZoneCoordinates.coordinates(forIdentifier: "UTC") == nil)
    #expect(TimeZoneCoordinates.coordinates(forIdentifier: "Etc/GMT+1") == nil)
}
