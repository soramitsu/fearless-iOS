import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

extension TransactionDetailsViewModelFactory {
    func createExtrinsViewModels(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> [WalletFormViewBindingProtocol]? {
        guard let chain = WalletAssetId(rawValue: data.assetId)?.chain else {
            return nil
        }

        var viewModels: [WalletFormViewBindingProtocol] = []

        populateTransactionId(
            in: &viewModels,
            data: data,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )

        populateSender(
            in: &viewModels,
            address: address,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )

        populateStatus(into: &viewModels, data: data, locale: locale)
        populateTime(into: &viewModels, data: data, locale: locale)

        if let module = data.peerFirstName {
            let title = R.string.localizable.commonModule(preferredLanguages: locale.rLanguages)
            populateTitleWithDetails(
                into: &viewModels,
                title: title,
                details: module.capitalized
            )
        }

        if let call = data.peerLastName {
            let title = R.string.localizable.commonCall(preferredLanguages: locale.rLanguages)
            populateTitleWithDetails(
                into: &viewModels,
                title: title,
                details: call.capitalized
            )
        }

        let feeTitle = R.string.localizable
            .commonNetworkFee(preferredLanguages: locale.rLanguages)
        populateAmount(into: &viewModels, title: feeTitle, data: data, locale: locale)

        return viewModels
    }

    func createExtrinsicAccessoryViewModel(
        data _: AssetTransactionData,
        commandFactory _: WalletCommandFactoryProtocol,
        locale _: Locale
    ) -> AccessoryViewModelProtocol? {
        nil
    }

    private func populateSender(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        address: String,
        chain: Chain,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable
            .transactionDetailsFrom(preferredLanguages: locale.rLanguages)
        populatePeerViewModel(
            in: &viewModelList,
            title: title,
            address: address,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )
    }
}
