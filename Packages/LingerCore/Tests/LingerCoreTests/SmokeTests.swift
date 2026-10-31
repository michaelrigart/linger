import Testing
@testable import LingerCore

@Test func appearanceRawValues() {
    #expect(Appearance.light.rawValue == "light")
    #expect(Appearance.dark.rawValue == "dark")
}
