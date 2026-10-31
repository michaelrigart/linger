import Testing
@testable import LingerCore

let brussels = Coordinates(latitude: 50.85, longitude: 4.35)

func expectCoords(_ c: Coordinates?, _ lat: Double, _ lon: Double, sourceLocation: SourceLocation = #_sourceLocation) {
    guard let c else {
        Issue.record("expected coordinates near \(lat), \(lon), got nil", sourceLocation: sourceLocation)
        return
    }
    #expect(abs(c.latitude - lat) <= 0.0001, sourceLocation: sourceLocation)
    #expect(abs(c.longitude - lon) <= 0.0001, sourceLocation: sourceLocation)
}
