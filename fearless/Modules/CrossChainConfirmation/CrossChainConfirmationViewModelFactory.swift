import Foundation
import SSFModels

protocol CrossChainConfirmationViewModelFactoryProtocol {
    func createViewModel(with data: CrossChainConfirmationData) -> CrossChainConfirmationViewModel
}

final class CrossChainConfirmationViewModelFactory: CrossChainConfirmationViewModelFactoryProtocol {
    func createViewModel(with data: CrossChainConfirmationData) -> CrossChainConfirmationViewModel {
        let originShadowColor = HexColorConverter.hexStringToUIColor(
            hex: data.originChainAsset.asset.color
        )?.cgColor
        let originSymbolViewModel = SymbolViewModel(
            symbolViewModel: data.originChainAsset.chain.icon.map { RemoteImageViewModel(url: $0) },
            shadowColor: originShadowColor
        )

        let destShadowColor = HexColorConverter.hexStringToUIColor(
            hex: data.originChainAsset.asset.color
        )?.cgColor
        let destSymbolViewModel = SymbolViewModel(
            symbolViewModel: data.destChainModel.icon.map { RemoteImageViewModel(url: $0) },
            shadowColor: destShadowColor
        )

        let doubleImageViewViewModel = PolkaswapDoubleSymbolViewModel(
            leftViewModel: originSymbolViewModel.symbolViewModel,
            rightViewModel: destSymbolViewModel.symbolViewModel,
            leftShadowColor: originShadowColor,
            rightShadowColor: destShadowColor
        )

        // Build optional origin preservation note for Asset Hub destinations
        var originNote: String?
        if Self.isTrustedAliaser(chain: data.destChainModel) {
            originNote = "Origin preserved via reserve transfer"
        }

        return CrossChainConfirmationViewModel(
            sendTo: data.recipientAddress,
            doubleImageViewViewModel: doubleImageViewViewModel,
            originalNetworkName: data.originChainAsset.chain.name,
            destNetworkName: data.destChainModel.name,
            amount: [data.displayAmount, data.originChainAsset.asset.symbolUppercased].joined(separator: " "),
            originalChainFee: data.originChainFee,
            destChainFee: data.destChainFee,
            originPreservationNote: originNote,
            totalBurned: Self.totalBurned(for: data)
        )
    }
}

private extension CrossChainConfirmationViewModelFactory {
    static func isTrustedAliaser(chain: ChainModel) -> Bool {
        chain.paraId == "1000"
    }

    /// The destination fee is added to the burn, so the user confirms the total that leaves the origin account
    /// whenever the fee is not zero.
    static func totalBurned(for data: CrossChainConfirmationData) -> String? {
        let precision = Int16(data.originChainAsset.asset.precision)
        guard data.destChainFeeDecimal > .zero,
              let feeInPlanks = data.destChainFeeDecimal.toSubstrateAmount(precision: precision),
              let total = Decimal.fromSubstrateAmount(data.amount + feeInPlanks, precision: precision) else {
            return nil
        }
        return [
            NSDecimalNumber(decimal: total).stringValue,
            data.originChainAsset.asset.symbolUppercased
        ].joined(separator: " ")
    }
}
