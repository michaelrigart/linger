import Foundation

public enum TimeZoneCoordinates {
    public static func coordinates(forIdentifier id: String) -> Coordinates? {
        table[id]
    }

    private static let table: [String: Coordinates] = {
        guard let url = Bundle.module.url(forResource: "zone", withExtension: "tab"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [:] }
        var result: [String: Coordinates] = [:]
        for line in text.split(whereSeparator: \.isNewline) where !line.hasPrefix("#") {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count >= 3, let parsed = parse(String(columns[1])) else { continue }
            result[String(columns[2])] = parsed
        }
        return result
    }()

    private static func parse(_ value: String) -> Coordinates? {
        let characters = Array(value)
        guard let split = characters.indices.dropFirst().first(where: { characters[$0] == "+" || characters[$0] == "-" })
        else { return nil }
        guard let latitude = decimal(characters[..<split], degreeDigits: 2),
              let longitude = decimal(characters[split...], degreeDigits: 3)
        else { return nil }
        return Coordinates(latitude: latitude, longitude: longitude)
    }

    private static func decimal(_ part: ArraySlice<Character>, degreeDigits: Int) -> Double? {
        guard let sign = part.first, sign == "+" || sign == "-" else { return nil }
        let digits = part.dropFirst()
        guard digits.allSatisfy(\.isNumber), digits.count == degreeDigits + 2 || digits.count == degreeDigits + 4
        else { return nil }
        let numbers = digits.compactMap { $0.wholeNumberValue }
        func number(_ range: Range<Int>) -> Double {
            Double(numbers[range].reduce(0) { $0 * 10 + $1 })
        }
        let degrees = number(0..<degreeDigits)
        let minutes = number(degreeDigits..<(degreeDigits + 2))
        let seconds = digits.count > degreeDigits + 2 ? number((degreeDigits + 2)..<(degreeDigits + 4)) : 0
        let magnitude = degrees + minutes / 60 + seconds / 3600
        return sign == "-" ? -magnitude : magnitude
    }
}
