import Foundation
import SSFModels
import RobinHood

enum SubqueryPriceFetcherError: Error {
    case invalidEndpoint
    case invalidPriceIdentifier
    case invalidResponse
    case invalidPagination
    case paginationLimit
    case requestTooLarge
}

enum PriceValueValidator {
    static func isStrictlyPositiveDecimal(
        _ value: String,
        maximumBytes: Int
    ) -> Bool {
        guard
            value.isNotEmpty,
            value.utf8.count <= maximumBytes,
            value == value.trimmingCharacters(in: .whitespacesAndNewlines),
            value.range(
                of: #"^[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$"#,
                options: .regularExpression
            ) == value.startIndex ..< value.endIndex,
            let decimal = Decimal(
                string: value,
                locale: Locale(identifier: "en_US_POSIX")
            )
        else {
            return false
        }

        return decimal > 0
    }
}

protocol SoraSubqueryPriceFetcher {
    func fetchPriceOperation(
        for chainAssets: [ChainAsset]
    ) -> BaseOperation<[PriceData]>
}
