import Foundation
import FearlessUtils
import SoraFoundation
import SoraKeystore

struct WalletSendViewFactory {
    static func createView(
        receiverAddress: String,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        scamInfo: ScamInfo?,
        transferFinishBlock: WalletTransferFinishBlock?
    ) -> WalletSendViewProtocol? {
        guard let interactor = createInteractor(
            chainAsset: chainAsset,
            receiverAddress: receiverAddress
        ) else {
            return nil
        }

        let wireframe = WalletSendWireframe()
        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
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
            chainAsset: chainAsset,
            receiverAddress: receiverAddress,
            scamInfo: scamInfo,
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
        chainAsset: ChainAsset,
        receiverAddress: String
    ) -> WalletSendInteractor? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }
        let operationManager = OperationManagerFacade.sharedManager
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(
                for: chainAsset.chain.chainId
            ) else {
            return nil
        }

        guard let accountResponse = selectedMetaAccount.fetch(
            for: chainAsset.chain.accountRequest()
        ) else {
            return nil
        }

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chainAsset.chain.chainFormat,
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
