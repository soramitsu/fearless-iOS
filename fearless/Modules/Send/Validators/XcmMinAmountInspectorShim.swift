import Foundation
import BigInt
import SSFModels

enum AppXcmMinAmountError: Error, Equatable {
    /// Below the reviewed minimum; carries the reviewed display text, such as "1.1 LLD".
    case minAmountError(String)
    /// No reviewed definition matches the exact origin asset, precision and destination, so no minimum is known.
    case ruleUnavailable
}

protocol AppXcmMinAmountInspector {
    func inspectMin(
        amount: BigUInt,
        origin: ChainAsset,
        destination: ChainModel
    ) throws
}

/// Minimums come from the reviewed route definition of the exact origin asset and direction, in the origin's base
/// units. A route the registry does not review fails closed instead of passing without a check.
final class AppXcmMinAmountInspectorImpl: AppXcmMinAmountInspector {
    private let definitions: [ReviewedXcmRouteDefinition]

    init(definitions: [ReviewedXcmRouteDefinition] = ReviewedXcmRouteRegistry.routes) {
        self.definitions = definitions
    }

    func inspectMin(
        amount: BigUInt,
        origin: ChainAsset,
        destination: ChainModel
    ) throws {
        let matches = definitions.filter {
            $0.originChainId == origin.chain.chainId &&
                $0.originAssetId == origin.asset.id &&
                $0.originPrecision == origin.asset.precision &&
                $0.execution.asset.validates(origin.asset) &&
                $0.destinationChainIds.contains(destination.chainId)
        }
        guard matches.count == 1, let definition = matches.first else {
            throw AppXcmMinAmountError.ruleUnavailable
        }
        // A definition without a minimum was reviewed as having none.
        guard let minimum = definition.execution.minimumAmount else {
            return
        }
        guard let minimumAmount = BigUInt(minimum, radix: 10) else {
            throw AppXcmMinAmountError.ruleUnavailable
        }
        guard amount >= minimumAmount else {
            throw AppXcmMinAmountError.minAmountError(definition.minimumDisplay)
        }
    }
}
