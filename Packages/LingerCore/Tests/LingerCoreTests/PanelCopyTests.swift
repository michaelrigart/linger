import Foundation
import Testing
@testable import LingerCore

@Test func statusLines() {
    #expect(PanelCopy.statusLine(.active(since: utc("2026-10-30T07:12:00Z")), locale: enGB, timeZone: tz) == "Since 08:12")
    #expect(PanelCopy.statusLine(.paused(until: utc("2026-10-30T14:30:00Z")), locale: enGB, timeZone: tz) == "Paused until 15:30")
    #expect(PanelCopy.statusLine(.off, locale: enGB, timeZone: tz) == "Off")
    #expect(PanelCopy.statusLine(.steppingAside(target: .dark), locale: enGB, timeZone: tz) == "Stepping aside so macOS can switch to Dark")
    #expect(PanelCopy.statusLine(.needsPermission, locale: enGB, timeZone: tz) == "Needs permission to keep you active")
    #expect(PanelCopy.title(.active(since: .now)) == "Keeping you active")
}

@Test func switchLine() {
    #expect(PanelCopy.switchLine((.dark, utc("2026-10-30T16:48:50Z")), appearanceIsAuto: true, stepAsideEnabled: true, locale: enGB, timeZone: tz)
            == "Dark mode around 17:49. I'll step aside for a moment once you're away so macOS can switch.")
    #expect(PanelCopy.switchLine(nil, appearanceIsAuto: false, stepAsideEnabled: true, locale: enGB, timeZone: tz)
            == "Set Appearance to Auto in System Settings to switch light and dark automatically.")
    #expect(PanelCopy.switchLine((.dark, .now), appearanceIsAuto: true, stepAsideEnabled: false, locale: enGB, timeZone: tz) == nil)
}

@Test func locationAndIcons() {
    #expect(PanelCopy.locationLine(identifier: "Europe/Brussels", coordinates: Coordinates(latitude: 50.8333, longitude: 4.3333)) == "Estimated from time zone (Europe/Brussels)")
    #expect(PanelCopy.locationLine(identifier: "UTC", coordinates: nil) == "Location unknown")
    #expect(PanelCopy.iconSymbol(.active(since: .now)) == "circle.fill")
    #expect(PanelCopy.iconSymbol(.steppingAside(target: .light)) == "circle.lefthalf.filled")
    for s in [EngineStatus.off, .needsPermission, .paused(until: .now)] { #expect(PanelCopy.iconSymbol(s) == "circle") }
}
