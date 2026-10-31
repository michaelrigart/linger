import Foundation

public struct LingerSettings: Equatable, Sendable {
    public var isOn: Bool
    public var pausedUntil: Date?
    public var idleDelay: TimeInterval
    public var stepAsideEnabled: Bool
    public var gapBudget: TimeInterval

    public static let idleDelayChoices: [TimeInterval] = [30, 60, 120, 180]
    public static let gapBudgetChoices: [TimeInterval] = [300, 600, 900, 1800]

    public init(
        isOn: Bool = true,
        pausedUntil: Date? = nil,
        idleDelay: TimeInterval = 60,
        stepAsideEnabled: Bool = true,
        gapBudget: TimeInterval = 900
    ) {
        self.isOn = isOn
        self.pausedUntil = pausedUntil
        self.idleDelay = idleDelay
        self.stepAsideEnabled = stepAsideEnabled
        self.gapBudget = gapBudget
    }

    public func isPaused(at now: Date) -> Bool {
        guard let pausedUntil else { return false }
        return pausedUntil > now
    }
}

public enum PauseDuration: CaseIterable, Sendable {
    case fifteenMinutes, oneHour, today

    public func end(from now: Date, calendar: Calendar) -> Date {
        switch self {
        case .fifteenMinutes: now.addingTimeInterval(900)
        case .oneHour: now.addingTimeInterval(3600)
        case .today:
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
                ?? now.addingTimeInterval(86_400)
        }
    }
}
