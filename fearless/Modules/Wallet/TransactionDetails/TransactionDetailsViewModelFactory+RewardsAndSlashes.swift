import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils
import IrohaCrypto

extension TransactionDetailsViewModelFactory {
    func createRewardAndSlashViewModels(
        isReward: Bool,
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

        populateValidator(
            in: &viewModels,
            accountId: data.peerId,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )

        populateStatus(into: &viewModels, data: data, locale: locale)
        populateTime(into: &viewModels, data: data, locale: locale)

        let title = isReward ? "Reward" : "Slash"
        populateAmount(into: &viewModels, title: title, data: data, locale: locale)

        return viewModels
    }

    func createRewardAndSlashAccessoryViewModel(
        data _: AssetTransactionData,
        commandFactory _: WalletCommandFactoryProtocol,
        locale _: Locale
    ) -> AccessoryViewModelProtocol? {
        nil
    }

    private func populateValidator(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        accountId: String,
        chain: Chain,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let factory = SS58AddressFactory()

        if let peerId = try? Data(hexString: accountId),
           let peerAddress = try? factory
           .addressFromAccountId(data: peerId, type: chain.addressType) {
            populatePeerViewModel(
                in: &viewModelList,
                title: "Validator",
                address: peerAddress,
                chain: chain,
                commandFactory: commandFactory,
                locale: locale
            )
        }
    }
}
