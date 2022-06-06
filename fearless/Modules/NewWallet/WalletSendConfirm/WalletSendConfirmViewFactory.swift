import Foundation
import BigInt
import FearlessUtils
import SoraFoundation
import SoraKeystore

struct WalletSendConfirmViewFactory {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        receiverAddress: String,
        amount: Decimal,
        tip: Decimal?,
        transferFinishBlock: WalletTransferFinishBlock?
    ) -> WalletSendConfirmViewProtocol? {
        guard let interactor = createInteractor(
            chain: chain,
            asset: asset,
            receiverAddress: receiverAddress
        ),
            let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        let wireframe = WalletSendConfirmWireframe()

        let accountViewModelFactory = AccountViewModelFactory(iconGenerator: PolkadotIconGenerator())
        let assetInfo = asset.displayInfo(with: chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: selectedMetaAccount
        )

        let dataValidatingFactory = WalletDataValidatingFactory(presentable: wireframe)

        let viewModelFactory = WalletSendConfirmViewModelFactory(
            amountFormatterFactory: AssetBalanceFormatterFactory(),
            assetInfo: assetInfo
        )

        let presenter = WalletSendConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            accountViewModelFactory: accountViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            walletSendConfirmViewModelFactory: viewModelFactory,
            logger: Logger.shared,
            asset: asset,
            selectedAccount: selectedMetaAccount,
            chain: chain,
            receiverAddress: receiverAddress,
            amount: amount,
            tip: tip,
            transferFinishBlock: transferFinishBlock
        )

        let view = WalletSendConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        dataValidatingFactory.view = view
        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        chain: ChainModel,
        asset: AssetModel,
        receiverAddress: String
    ) -> WalletSendConfirmInteractor? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        guard let accountResponse = selectedMetaAccount.fetch(for: chain.accountRequest()) else {
            return nil
        }

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let feeProxy = ExtrinsicFeeProxy()

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        guard let accountResponse = selectedMetaAccount.fetch(for: chain.accountRequest()) else {
            return nil
        }

        let keystore = Keychain()
        let signingWrapper = SigningWrapper(
            keystore: keystore,
            metaId: selectedMetaAccount.metaId,
            accountResponse: accountResponse
        )

        return WalletSendConfirmInteractor(
            selectedMetaAccount: selectedMetaAccount,
            chain: chain,
            asset: asset,
            receiverAddress: receiverAddress,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
                selectedMetaAccount: selectedMetaAccount
            ),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            operationManager: operationManager,
            signingWrapper: signingWrapper
        )
    }
}
