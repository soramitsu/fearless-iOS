import Foundation
import CommonWallet

class BaseAssetViewModelFactory: AccountListViewModelFactoryProtocol {
    let address: String
    let chain: Chain
    let purchaseProvider: PurchaseProviderProtocol

    init(address: String, chain: Chain, purchaseProvider: PurchaseProviderProtocol) {
        self.address = address
        self.chain = chain
        self.purchaseProvider = purchaseProvider
    }

    func createAssetViewModel(for asset: WalletAsset,
                              balance: BalanceData,
                              commandFactory: WalletCommandFactoryProtocol,
                              locale: Locale) -> WalletViewModelProtocol? {
        return nil
    }

    func createActionsViewModel(for assetId: String?,
                                commandFactory: WalletCommandFactoryProtocol,
                                locale: Locale) -> WalletViewModelProtocol? {
        let sendCommand: WalletCommandProtocol = commandFactory.prepareSendCommand(for: assetId)
        let sendTitle = R.string.localizable
            .walletSendTitle(preferredLanguages: locale.rLanguages)
        let sendViewModel = WalletActionViewModel(title: sendTitle,
                                                  command: sendCommand)

        let receiveCommand: WalletCommandProtocol = commandFactory.prepareReceiveCommand(for: assetId)

        let receiveTitle = R.string.localizable
            .walletAssetReceive(preferredLanguages: locale.rLanguages)
        let receiveViewModel = WalletActionViewModel(title: receiveTitle,
                                                     command: receiveCommand)

        let walletAssetId: WalletAssetId?

        if let assetId = assetId {
            walletAssetId = WalletAssetId(rawValue: assetId)
        } else {
            walletAssetId = nil
        }

        let actions = purchaseProvider.buildPurchaseAction(for: chain,
                                                           assetId: walletAssetId,
                                                           address: address)

        let buyCommand: WalletCommandProtocol?
        if !actions.isEmpty {
            buyCommand = WalletBuyCommand(actions: actions, commandFactory: commandFactory)
        } else {
            buyCommand = nil
        }

        let buyTitle = R.string.localizable.walletAssetBuy(preferredLanguages: locale.rLanguages)
        let buyViewModel = WalletDisablingAction(title: buyTitle, command: buyCommand)

        return WalletActionsViewModel(send: sendViewModel,
                                      receive: receiveViewModel,
                                      buy: buyViewModel)
    }
}
