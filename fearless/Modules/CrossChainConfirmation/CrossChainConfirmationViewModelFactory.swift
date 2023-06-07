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

        return CrossChainConfirmationViewModel(
            sendTo: data.recipientAddress,
            doubleImageViewViewModel: doubleImageViewViewModel,
            originalNetworkName: data.originChainAsset.chain.name,
            destNetworkName: data.destChainModel.name,
            amount: data.displayAmount,
            originalChainFee: data.originChainFee,
            destChainFee: data.destChainFee
        )
    }
}
