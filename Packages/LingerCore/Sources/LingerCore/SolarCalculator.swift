import Foundation

public enum SolarCalculator {
    public static func altitude(at date: Date, coordinates: Coordinates) -> Double {
        let seconds = date.timeIntervalSince1970
        let jd = seconds / 86400 + 2440587.5
        let t = (jd - 2451545) / 36525
        let l0 = positiveModulo(280.46646 + t * (36000.76983 + t * 0.0003032), 360)
        let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let mr = radians(m)
        let c = sin(mr) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * mr) * (0.019993 - 0.000101 * t)
            + sin(3 * mr) * 0.000289
        let trueLongitude = l0 + c
        let omega = 125.04 - 1934.136 * t
        let apparentLongitude = trueLongitude - 0.00569 - 0.00478 * sin(radians(omega))
        let meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliquity = meanObliquity + 0.00256 * cos(radians(omega))
        let declination = asin(sin(radians(obliquity)) * sin(radians(apparentLongitude)))
        let y = pow(tan(radians(obliquity / 2)), 2)
        let l0r = radians(l0)
        let equationOfTime = 4 * degrees(
            y * sin(2 * l0r)
                - 2 * e * sin(mr)
                + 4 * e * y * sin(mr) * cos(2 * l0r)
                - 0.5 * y * y * sin(4 * l0r)
                - 1.25 * e * e * sin(2 * mr)
        )
        let minutesOfDay = positiveModulo(seconds, 86400) / 60
        let trueSolarTime = positiveModulo(minutesOfDay + equationOfTime + 4 * coordinates.longitude, 1440)
        let hourAngle = trueSolarTime / 4 >= 0 ? trueSolarTime / 4 - 180 : trueSolarTime / 4 + 180
        let latitude = radians(coordinates.latitude)
        let cosZenith = sin(latitude) * sin(declination)
            + cos(latitude) * cos(declination) * cos(radians(hourAngle))
        return 90 - degrees(acos(max(-1, min(1, cosZenith))))
    }

    public static func nextCrossing(
        of altitude: Double,
        rising: Bool,
        after date: Date,
        coordinates: Coordinates,
        within: TimeInterval = 172_800
    ) -> Date? {
        let step: TimeInterval = 60
        var previousTime = date
        var previous = Self.altitude(at: previousTime, coordinates: coordinates)
        var elapsed: TimeInterval = 0
        while elapsed < within {
            elapsed += step
            let time = date.addingTimeInterval(elapsed)
            let current = Self.altitude(at: time, coordinates: coordinates)
            let crossed = rising
                ? previous < altitude && altitude <= current
                : previous > altitude && altitude >= current
            if crossed {
                return bisect(
                    altitude: altitude, rising: rising, from: previousTime, to: time, coordinates: coordinates
                )
            }
            previousTime = time
            previous = current
        }
        return nil
    }

    public static func altitudeRange(
        onDayContaining date: Date,
        timeZone: TimeZone,
        coordinates: Coordinates
    ) -> ClosedRange<Double> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        var low = Double.infinity
        var high = -Double.infinity
        var time = start
        while time < end {
            let value = altitude(at: time, coordinates: coordinates)
            low = min(low, value)
            high = max(high, value)
            time = time.addingTimeInterval(300)
        }
        return low...high
    }

    private static func bisect(
        altitude: Double,
        rising: Bool,
        from lower: Date,
        to upper: Date,
        coordinates: Coordinates
    ) -> Date {
        var lower = lower
        var upper = upper
        while upper.timeIntervalSince(lower) > 1 {
            let middle = lower.addingTimeInterval(upper.timeIntervalSince(lower) / 2)
            let value = Self.altitude(at: middle, coordinates: coordinates)
            let reached = rising ? value >= altitude : value <= altitude
            if reached { upper = middle } else { lower = middle }
        }
        return upper
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }

    private static func positiveModulo(_ value: Double, _ modulus: Double) -> Double {
        let r = value.truncatingRemainder(dividingBy: modulus)
        return r < 0 ? r + modulus : r
    }
}
