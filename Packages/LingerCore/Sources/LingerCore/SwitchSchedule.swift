import Foundation

public enum SwitchSchedule {
    public static let darkThreshold = -5.0
    public static let lightThreshold = -1.0

    public static func dueSwitch(
        at date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        effective: Appearance
    ) -> Appearance? {
        guard reachesBothThresholds(on: date, coordinates: coordinates, timeZone: timeZone) else { return nil }
        let altitude = SolarCalculator.altitude(at: date, coordinates: coordinates)
        let expected: Appearance
        if altitude >= lightThreshold {
            expected = .light
        } else if altitude <= darkThreshold {
            expected = .dark
        } else {
            return nil
        }
        return expected == effective ? nil : expected
    }

    public static func nextStepAside(
        after date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        effective: Appearance
    ) -> (target: Appearance, at: Date)? {
        if let due = dueSwitch(at: date, coordinates: coordinates, timeZone: timeZone, effective: effective) {
            return (due, date)
        }
        let target: Appearance = effective == .light ? .dark : .light
        let crossing = effective == .light
            ? SolarCalculator.nextCrossing(of: darkThreshold, rising: false, after: date, coordinates: coordinates)
            : SolarCalculator.nextCrossing(of: lightThreshold, rising: true, after: date, coordinates: coordinates)
        guard let crossing,
              reachesBothThresholds(on: crossing, coordinates: coordinates, timeZone: timeZone)
        else { return nil }
        return (target, crossing)
    }

    private static func reachesBothThresholds(on date: Date, coordinates: Coordinates, timeZone: TimeZone) -> Bool {
        let range = SolarCalculator.altitudeRange(onDayContaining: date, timeZone: timeZone, coordinates: coordinates)
        return range.upperBound >= lightThreshold && range.lowerBound <= darkThreshold
    }
}
