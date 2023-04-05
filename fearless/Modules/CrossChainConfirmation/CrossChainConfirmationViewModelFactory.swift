import Foundation

protocol CrossChainConfirmationViewModelFactoryProtocol {
    func createViewModel(with data: CrossChainConfirmationData) -> CrossChainConfirmationViewModel
}

final class CrossChainConfirmationViewModelFactory: CrossChainConfirmationViewModelFactoryProtocol {
    func createViewModel(with data: CrossChainConfirmationData) -> CrossChainConfirmationViewModel {
        let shadowColor = HexColorConverter.hexStringToUIColor(
            hex: data.originalChainAsset.asset.color
        )?.cgColor
        let symbolViewModel = SymbolViewModel(
            symbolViewModel: data.originalChainAsset.asset.icon.map { RemoteImageViewModel(url: $0) },
            shadowColor: shadowColor
        )

        return CrossChainConfirmationViewModel(
            symbolViewModel: symbolViewModel,
            originalNetworkName: data.originalChainAsset.chain.name,
            destNetworkName: data.destChainModel.name,
            amount: data.amountViewModel,
            originalChainFee: data.originalChainFee,
            destChainFee: data.destChainFee
        )
    }
}
