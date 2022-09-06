import Foundation
import FearlessUtils
import SoraFoundation
import SoraKeystore

struct WalletSendViewFactory {
    static func createView(
        receiverAddress: String,
        asset: AssetModel,
        chain: ChainModel,
        wallet: MetaAccountModel,
        transferFinishBlock: WalletTransferFinishBlock?
    ) -> WalletSendViewProtocol? {
        guard let interactor = createInteractor(chain: chain, asset: asset, receiverAddress: receiverAddress) else {
            return nil
        }

        let wireframe = WalletSendWireframe()
        let assetInfo = asset.displayInfo(with: chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )

        let dataValidatingFactory = WalletDataValidatingFactory(presentable: wireframe)

        let presenter = WalletSendPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared,
            asset: asset,
            receiverAddress: receiverAddress,
            chain: chain,
            transferFinishBlock: transferFinishBlock
        )

        let view = WalletSendViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        chain: ChainModel,
        asset: AssetModel,
        receiverAddress: String
    ) -> WalletSendInteractor? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }
        let chainAsset = ChainAsset(chain: chain, asset: asset)

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
        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let existentialDepositService = ExistentialDepositService(
            runtimeCodingService: runtimeService,
            operationManager: operationManager,
            engine: connection
        )

        return WalletSendInteractor(
            selectedMetaAccount: selectedMetaAccount,
            chainAsset: chainAsset,
            receiverAddress: receiverAddress,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: selectedMetaAccount
            ),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            operationManager: operationManager,
            existentialDepositService: existentialDepositService
        )
    }
}
