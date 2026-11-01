import AppKit
import Foundation
import LingerCore

enum AppearanceSource {
    static var isAuto: Bool {
        UserDefaults.standard.bool(forKey: "AppleInterfaceStyleSwitchesAutomatically")
    }

    @MainActor
    static var effective: Appearance {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }
}
