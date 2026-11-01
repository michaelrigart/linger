import Foundation

public enum PanelCopy {
    public static func statusLine(_ s: EngineStatus, locale: Locale, timeZone: TimeZone) -> String {
        switch s {
        case .active(let since): "Since \(clock(since, locale: locale, timeZone: timeZone))"
        case .paused(let until): "Paused until \(clock(until, locale: locale, timeZone: timeZone))"
        case .off: "Off"
        case .steppingAside(let target): "Stepping aside so macOS can switch to \(target.label)"
        case .needsPermission: "Needs permission to keep you active"
        }
    }

    public static func title(_ s: EngineStatus) -> String {
        switch s {
        case .active, .steppingAside: "Keeping you active"
        case .paused: "Paused"
        case .off, .needsPermission: "Not keeping you active"
        }
    }

    public static func switchLine(
        _ next: (target: Appearance, at: Date)?,
        now: Date,
        appearanceIsAuto: Bool,
        stepAsideEnabled: Bool,
        locale: Locale,
        timeZone: TimeZone
    ) -> String? {
        guard stepAsideEnabled else { return nil }
        guard appearanceIsAuto else {
            return "Set Appearance to Auto in System Settings to switch light and dark automatically."
        }
        guard let next else { return nil }
        guard next.at > now else {
            return "\(next.target.label) mode is due. I'll step aside once you're away so macOS can switch."
        }
        let time = clock(next.at, locale: locale, timeZone: timeZone)
        return "\(next.target.label) mode around \(time). I'll step aside for a moment once you're away so macOS can switch."
    }

    public static func locationLine(identifier: String, coordinates: Coordinates?) -> String {
        coordinates == nil ? "Location unknown" : "Estimated from time zone (\(identifier))"
    }

    public static func menuBarImage(_ s: EngineStatus) -> String {
        switch s {
        case .active: "LingerMenuBar"
        case .steppingAside: "LingerMenuBarHalf"
        case .off, .needsPermission, .paused: "LingerMenuBarOutline"
        }
    }

    public static func clock(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
        let rounded = Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / 60).rounded() * 60)
        let h24 = locale.hourCycle == .zeroToTwentyThree || locale.hourCycle == .oneToTwentyFour
        return rounded.formatted(
            Date.FormatStyle(locale: locale, timeZone: timeZone)
                .hour(h24 ? .twoDigits(amPM: .abbreviated) : .defaultDigits(amPM: .abbreviated))
                .minute(.twoDigits)
        )
    }
}

extension Appearance {
    fileprivate var label: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
