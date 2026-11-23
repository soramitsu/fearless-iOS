import Foundation

/// An exact, non-negative token amount in the asset's smallest unit.
///
/// `units` holds base-10 digits only (no sign, no separators, no leading
/// zeros; zero is `"0"`), so amounts of any size (u128 balances, u256 ERC-20
/// values) survive untouched between the engine and the UI. Use `Decimal`
/// (`decimalValue`) only for display and fiat estimates, never for signing.
public struct TokenAmount: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public static let maximumDecimals = 77

    public let units: String
    public let decimals: Int

    /// Creates an amount from smallest-unit digits. Returns nil for anything
    /// other than ASCII digits or for decimals outside `0...maximumDecimals`.
    public init?(units: String, decimals: Int) {
        guard (0...Self.maximumDecimals).contains(decimals),
              !units.isEmpty,
              units.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 })
        else { return nil }
        self.units = Self.normalized(units)
        self.decimals = decimals
    }

    public static func zero(decimals: Int) -> TokenAmount {
        TokenAmount(trustedUnits: "0", decimals: max(0, min(decimals, maximumDecimals)))
    }

    /// Parses user input such as `"1.5"`, `"1,5"` (in comma locales) or
    /// `"1 234.56"`. Returns nil if the text is not a plain non-negative
    /// number or has more fraction digits than the asset supports: the amount
    /// is never rounded silently.
    public init?(decimalString text: String, decimals: Int, locale: Locale = .current) {
        guard (0...Self.maximumDecimals).contains(decimals) else { return nil }
        let decimalSeparator = locale.decimalSeparator ?? "."
        var cleaned = String(text.unicodeScalars.filter { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar) && scalar != "'" && scalar != "\u{2019}"
        }.map(Character.init))
        guard !cleaned.isEmpty else { return nil }

        if decimalSeparator == "," {
            if cleaned.contains(",") {
                cleaned = cleaned.replacingOccurrences(of: ".", with: "")
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            }
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }

        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        let integerPart = String(parts[0])
        let fractionPart = parts.count == 2 ? String(parts[1]) : ""
        guard !(integerPart.isEmpty && fractionPart.isEmpty),
              integerPart.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }),
              fractionPart.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 })
        else { return nil }

        var fraction = fractionPart
        while fraction.count > decimals, fraction.hasSuffix("0") {
            fraction.removeLast()
        }
        guard fraction.count <= decimals else { return nil }
        let padded = fraction + String(repeating: "0", count: decimals - fraction.count)
        self.init(trustedUnits: Self.normalized((integerPart.isEmpty ? "0" : integerPart) + padded), decimals: decimals)
    }

    private init(trustedUnits: String, decimals: Int) {
        units = trustedUnits
        self.decimals = decimals
    }

    public var isZero: Bool { units == "0" }

    /// Whole-token digits (e.g. `"12"` for 12.5).
    public var integerDigits: String {
        guard units.count > decimals else { return "0" }
        return String(units.prefix(units.count - decimals))
    }

    /// Fraction digits padded to `decimals` (e.g. `"5000"` for 12.5 with 4 decimals).
    public var fractionDigits: String {
        guard decimals > 0 else { return "" }
        if units.count > decimals {
            return String(units.suffix(decimals))
        }
        return String(repeating: "0", count: decimals - units.count) + units
    }

    /// Plain machine form with `.` and no grouping, trailing zeros removed
    /// (`"12.5"`, `"0"`). Stable across locales; suitable for copying.
    public var plainString: String {
        var fraction = fractionDigits
        while fraction.hasSuffix("0") {
            fraction.removeLast()
        }
        return fraction.isEmpty ? integerDigits : "\(integerDigits).\(fraction)"
    }

    public var description: String { plainString }

    /// Approximate value for display and fiat estimates only.
    public var decimalValue: Decimal {
        Decimal(string: plainString, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    /// Locale-formatted amount truncated (never rounded up) to
    /// `maximumFractionDigits`. A non-zero amount that would print as zero is
    /// shown as `"< 0.0001"` (for four digits) so a balance never looks empty.
    public func formatted(
        maximumFractionDigits: Int = 4,
        minimumFractionDigits: Int = 0,
        locale: Locale = .current
    ) -> String {
        let maxDigits = max(0, maximumFractionDigits)
        let minDigits = max(0, min(minimumFractionDigits, maxDigits))
        var fraction = String(fractionDigits.prefix(maxDigits))
        while fraction.count > minDigits, fraction.hasSuffix("0") {
            fraction.removeLast()
        }
        if fraction.count < minDigits {
            fraction += String(repeating: "0", count: minDigits - fraction.count)
        }
        let decimalSeparator = locale.decimalSeparator ?? "."
        let integer = Self.grouped(integerDigits, separator: locale.groupingSeparator ?? ",")
        let truncatedIsZero = integerDigits == "0" && !fraction.contains(where: { $0 != "0" })
        if truncatedIsZero && !isZero {
            let smallest = maxDigits == 0
                ? "1"
                : "0" + decimalSeparator + String(repeating: "0", count: maxDigits - 1) + "1"
            return "< " + smallest
        }
        return fraction.isEmpty ? integer : integer + decimalSeparator + fraction
    }

    /// Value in fiat for a unit price. Approximate (Decimal), for display.
    public func fiatValue(unitPrice: Decimal) -> Decimal {
        decimalValue * unitPrice
    }

    // MARK: - Arithmetic (exact, same-decimals)

    /// Sum of two amounts of the same asset. Returns nil if decimals differ.
    public func adding(_ other: TokenAmount) -> TokenAmount? {
        guard decimals == other.decimals else { return nil }
        return TokenAmount(trustedUnits: Self.add(units, other.units), decimals: decimals)
    }

    /// Difference, or nil if `other` is larger or decimals differ.
    public func subtracting(_ other: TokenAmount) -> TokenAmount? {
        guard decimals == other.decimals, Self.compare(units, other.units) != .orderedAscending else { return nil }
        return TokenAmount(trustedUnits: Self.subtract(units, other.units), decimals: decimals)
    }

    /// Difference clamped at zero (decimals must match, otherwise zero).
    public func subtractingClamped(_ other: TokenAmount) -> TokenAmount {
        subtracting(other) ?? .zero(decimals: decimals)
    }

    public static func < (lhs: TokenAmount, rhs: TokenAmount) -> Bool {
        let scale = max(lhs.decimals, rhs.decimals)
        let left = lhs.isZero ? "0" : lhs.units + String(repeating: "0", count: scale - lhs.decimals)
        let right = rhs.isZero ? "0" : rhs.units + String(repeating: "0", count: scale - rhs.decimals)
        return compare(left, right) == .orderedAscending
    }

    // MARK: - Digit-string helpers

    static func normalized(_ digits: String) -> String {
        let trimmed = digits.drop(while: { $0 == "0" })
        return trimmed.isEmpty ? "0" : String(trimmed)
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        if lhs.count != rhs.count {
            return lhs.count < rhs.count ? .orderedAscending : .orderedDescending
        }
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    static func add(_ lhs: String, _ rhs: String) -> String {
        let left = Array(lhs.utf8.reversed())
        let right = Array(rhs.utf8.reversed())
        var result: [UInt8] = []
        result.reserveCapacity(max(left.count, right.count) + 1)
        var carry: UInt8 = 0
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] - 0x30 : 0
            let b = index < right.count ? right[index] - 0x30 : 0
            let sum = a + b + carry
            result.append(sum % 10 + 0x30)
            carry = sum / 10
        }
        if carry > 0 { result.append(carry + 0x30) }
        return normalized(String(decoding: result.reversed(), as: UTF8.self))
    }

    /// `lhs - rhs`; caller guarantees `lhs >= rhs`.
    static func subtract(_ lhs: String, _ rhs: String) -> String {
        let left = Array(lhs.utf8.reversed())
        let right = Array(rhs.utf8.reversed())
        var result: [UInt8] = []
        result.reserveCapacity(left.count)
        var borrow: Int = 0
        for index in 0..<left.count {
            var digit = Int(left[index]) - 0x30 - borrow
            digit -= index < right.count ? Int(right[index]) - 0x30 : 0
            if digit < 0 {
                digit += 10
                borrow = 1
            } else {
                borrow = 0
            }
            result.append(UInt8(digit) + 0x30)
        }
        return normalized(String(decoding: result.reversed(), as: UTF8.self))
    }

    static func grouped(_ digits: String, separator: String) -> String {
        guard digits.count > 3, !separator.isEmpty else { return digits }
        var groups: [Substring] = []
        var end = digits.endIndex
        while end > digits.startIndex {
            let start = digits.index(end, offsetBy: -3, limitedBy: digits.startIndex) ?? digits.startIndex
            groups.append(digits[start..<end])
            end = start
        }
        return groups.reversed().joined(separator: separator)
    }
}
