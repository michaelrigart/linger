import Foundation
import LingerCore

final class SettingsStore {
    private enum Key {
        static let isOn = "isOn"
        static let pausedUntil = "pausedUntil"
        static let idleDelay = "idleDelay"
        static let stepAsideEnabled = "stepAsideEnabled"
        static let gapBudget = "gapBudget"
        static let loginItemConfigured = "loginItemConfigured"
    }

    private let defaults = UserDefaults.standard

    var hasStoredIsOn: Bool {
        defaults.object(forKey: Key.isOn) != nil
    }

    var loginItemConfigured: Bool {
        get { defaults.bool(forKey: Key.loginItemConfigured) }
        set { defaults.set(newValue, forKey: Key.loginItemConfigured) }
    }

    func load() -> LingerSettings {
        var settings = LingerSettings()
        if let isOn = defaults.object(forKey: Key.isOn) as? Bool {
            settings.isOn = isOn
        }
        settings.pausedUntil = defaults.object(forKey: Key.pausedUntil) as? Date
        if let idleDelay = defaults.object(forKey: Key.idleDelay) as? Double,
           LingerSettings.idleDelayChoices.contains(idleDelay) {
            settings.idleDelay = idleDelay
        }
        if let stepAside = defaults.object(forKey: Key.stepAsideEnabled) as? Bool {
            settings.stepAsideEnabled = stepAside
        }
        if let gapBudget = defaults.object(forKey: Key.gapBudget) as? Double,
           LingerSettings.gapBudgetChoices.contains(gapBudget) {
            settings.gapBudget = gapBudget
        }
        return settings
    }

    func save(_ settings: LingerSettings) {
        defaults.set(settings.isOn, forKey: Key.isOn)
        if let pausedUntil = settings.pausedUntil {
            defaults.set(pausedUntil, forKey: Key.pausedUntil)
        } else {
            defaults.removeObject(forKey: Key.pausedUntil)
        }
        defaults.set(settings.idleDelay, forKey: Key.idleDelay)
        defaults.set(settings.stepAsideEnabled, forKey: Key.stepAsideEnabled)
        defaults.set(settings.gapBudget, forKey: Key.gapBudget)
    }
}
