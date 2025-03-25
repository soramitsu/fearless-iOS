import Foundation

protocol CrossChainConfirmationViewModelFactoryProtocol {
    func createViewModel(with data: CrossChainConfirmationData) -> CrossChainConfirmationViewModel
}

final class CrossChainConfirmationViewModelFactory: CrossChainConfirmationViewModelFactoryProtocol {
    func createViewModel(with data: CrossChainConfirmationData) -> CrossChainConfirmationViewModel {
        let originShadowColor = HexColorConverter.hexStringToUIColor(
            hex: data.originChainAsset.asset.color
        )?.cgColor
        let originSymbolViewModel = SymbolViewModel(
            iconViewModel: data.originChainAsset.chain.icon.map { RemoteImageViewModel(url: $0) },
            shadowColor: originShadowColor
        )

        let destShadowColor = HexColorConverter.hexStringToUIColor(
            hex: data.originChainAsset.asset.color
        )?.cgColor
        let destSymbolViewModel = SymbolViewModel(
            iconViewModel: data.destChainModel.icon.map { RemoteImageViewModel(url: $0) },
            shadowColor: destShadowColor
        )

        let doubleImageViewViewModel = PolkaswapDoubleSymbolViewModel(
            leftViewModel: originSymbolViewModel.iconViewModel,
            rightViewModel: destSymbolViewModel.iconViewModel,
            leftShadowColor: originShadowColor,
            rightShadowColor: destShadowColor
        )

        return CrossChainConfirmationViewModel(
            sendTo: data.recipientAddress,
            doubleImageViewViewModel: doubleImageViewViewModel,
            originalNetworkName: data.originChainAsset.chain.name,
            destNetworkName: data.destChainModel.name,
            amount: [data.displayAmount, data.originChainAsset.asset.symbolUppercased].joined(separator: " "),
            originalChainFee: data.originChainFee,
            destChainFee: data.destChainFee
        )
    }
}
