import Foundation

enum AmountInputResult: Equatable {
    case rate(_ value: Decimal)
    case absolute(_ value: Decimal)

    func absoluteValue(from available: Decimal) -> Decimal {
        switch self {
        case let .rate(value):
            return max(value * available, 0.0)
        case let .absolute(value):
            return value
        }
    }
    
    var needsUpdateInputAfterChange: Bool {
        switch self {
        case .rate:
            return true
        case .absolute:
            return false
        }
    }
}
