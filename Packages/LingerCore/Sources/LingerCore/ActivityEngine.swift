import Foundation

public struct EngineInput: Sendable {
    public var now: Date
    public var uptime: TimeInterval
    public var idle: TimeInterval
    public var hasPostAccess: Bool
    public var isInhibited: Bool
    public var appearanceIsAuto: Bool
    public var effectiveAppearance: Appearance
    public var coordinates: Coordinates?
    public var timeZone: TimeZone

    public init(
        now: Date,
        uptime: TimeInterval,
        idle: TimeInterval,
        hasPostAccess: Bool,
        isInhibited: Bool,
        appearanceIsAuto: Bool,
        effectiveAppearance: Appearance,
        coordinates: Coordinates?,
        timeZone: TimeZone
    ) {
        self.now = now
        self.uptime = uptime
        self.idle = idle
        self.hasPostAccess = hasPostAccess
        self.isInhibited = isInhibited
        self.appearanceIsAuto = appearanceIsAuto
        self.effectiveAppearance = effectiveAppearance
        self.coordinates = coordinates
        self.timeZone = timeZone
    }
}

public enum EngineStatus: Equatable, Sendable {
    case needsPermission
    case off
    case paused(until: Date)
    case active(since: Date)
    case steppingAside(target: Appearance)
}

public struct EngineOutput: Equatable, Sendable {
    public var status: EngineStatus
    public var shouldPost: Bool

    public init(status: EngineStatus, shouldPost: Bool) {
        self.status = status
        self.shouldPost = shouldPost
    }
}

public struct ActivityEngine: Sendable {
    public static let postInterval: TimeInterval = 60
    public static let presenceTolerance: TimeInterval = 0.25

    private var lastPostUptime: TimeInterval?
    private var stepAside: (start: TimeInterval, target: Appearance)?
    private var attemptedThisAbsence = false
    private var activeSince: Date?

    public init() {}

    public mutating func tick(_ input: EngineInput, settings: LingerSettings) -> EngineOutput {
        if !input.hasPostAccess {
            endAbsence()
            activeSince = nil
            return EngineOutput(status: .needsPermission, shouldPost: false)
        }
        if !settings.isOn {
            endAbsence()
            activeSince = nil
            return EngineOutput(status: .off, shouldPost: false)
        }
        if let until = settings.pausedUntil, settings.isPaused(at: input.now) {
            endAbsence()
            activeSince = nil
            return EngineOutput(status: .paused(until: until), shouldPost: false)
        }
        if input.isInhibited {
            endAbsence()
            return EngineOutput(status: .active(since: activeSince ?? input.now), shouldPost: false)
        }

        guard isUserAway(idle: input.idle, uptime: input.uptime, idleDelay: settings.idleDelay) else {
            endAbsence()
            return EngineOutput(status: markActive(input.now), shouldPost: false)
        }

        if let current = stepAside {
            let budgetSpent = input.uptime - current.start >= settings.gapBudget
            let ended = input.effectiveAppearance == current.target
                || !input.appearanceIsAuto
                || !settings.stepAsideEnabled
                || budgetSpent
            guard ended else {
                return EngineOutput(status: .steppingAside(target: current.target), shouldPost: false)
            }
            if budgetSpent { attemptedThisAbsence = true }
            stepAside = nil
            return EngineOutput(status: markActive(input.now), shouldPost: true)
        }

        if !attemptedThisAbsence,
           settings.stepAsideEnabled,
           input.appearanceIsAuto,
           let coordinates = input.coordinates,
           let target = SwitchSchedule.dueSwitch(
               at: input.now,
               coordinates: coordinates,
               timeZone: input.timeZone,
               effective: input.effectiveAppearance
           ) {
            stepAside = (input.uptime, target)
            return EngineOutput(status: .steppingAside(target: target), shouldPost: false)
        }

        let due = lastPostUptime.map { input.uptime - $0 >= Self.postInterval } ?? true
        return EngineOutput(status: markActive(input.now), shouldPost: due)
    }

    public func isUserAway(idle: TimeInterval, uptime: TimeInterval, idleDelay: TimeInterval) -> Bool {
        guard let lastPostUptime else { return idle >= idleDelay }
        return idle >= (uptime - lastPostUptime) - Self.presenceTolerance
    }

    /// Re-reads idle and uptime, posts only if the user is still away, and records the post only if `post()` returned true.
    @discardableResult
    public mutating func postIfStillAway(
        idleDelay: TimeInterval,
        reread: () -> (idle: TimeInterval, uptime: TimeInterval),
        post: () -> Bool
    ) -> Bool {
        let now = reread()
        guard isUserAway(idle: now.idle, uptime: now.uptime, idleDelay: idleDelay), post() else { return false }
        didPost(atUptime: now.uptime)
        return true
    }

    mutating func didPost(atUptime uptime: TimeInterval) {
        lastPostUptime = uptime
    }

    private mutating func endAbsence() {
        lastPostUptime = nil
        stepAside = nil
        attemptedThisAbsence = false
    }

    private mutating func markActive(_ now: Date) -> EngineStatus {
        let since = activeSince ?? now
        activeSince = since
        return .active(since: since)
    }
}
