import Foundation

protocol CrossChainConfirmationViewModelFactoryProtocol {
    func createViewModel(with data: CrossChainConfirmationData) -> CrossChainConfirmationViewModel
}

final class CrossChainConfirmationViewModelFactory: CrossChainConfirmationViewModelFactoryProtocol {
    func createViewModel(with data: CrossChainConfirmationData) -> CrossChainConfirmationViewModel {
        let shadowColor = HexColorConverter.hexStringToUIColor(
            hex: data.originChainAsset.asset.color
        )?.cgColor
        let symbolViewModel = SymbolViewModel(
            symbolViewModel: data.originChainAsset.asset.icon.map { RemoteImageViewModel(url: $0) },
            shadowColor: shadowColor
        )

        return CrossChainConfirmationViewModel(
            symbolViewModel: symbolViewModel,
            originalNetworkName: data.originChainAsset.chain.name,
            destNetworkName: data.destChainModel.name,
            amount: data.amountViewModel,
            originalChainFee: data.originChainFee,
            destChainFee: data.destChainFee
        )
    }
}
