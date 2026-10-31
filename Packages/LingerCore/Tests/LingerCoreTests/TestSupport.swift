import Foundation
import Testing

func utc(_ s: String) -> Date {
    try! Date(s, strategy: .iso8601)
}

func expectNear(_ a: Date?, _ b: Date, sourceLocation: SourceLocation = #_sourceLocation) {
    guard let a else {
        Issue.record("expected a date near \(b), got nil", sourceLocation: sourceLocation)
        return
    }
    #expect(abs(a.timeIntervalSince(b)) <= 60, sourceLocation: sourceLocation)
}

let tz = TimeZone(identifier: "Europe/Brussels")!
let enGB = Locale(identifier: "en_GB")
