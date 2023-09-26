import Foundation
import BigInt
import SSFUtils
import SoraFoundation
import SoraKeystore
import SSFModels

struct WalletSendConfirmViewFactory {
    static func createView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        receiverAddress: String,
        amount: Decimal,
        tip: Decimal?,
        scamInfo: ScamInfo?
    ) -> WalletSendConfirmViewProtocol? {
        guard let interactor = createInteractor(
            wallet: wallet,
            chainAsset: chainAsset,
            receiverAddress: receiverAddress
        ) else {
            return nil
        }

        let wireframe = WalletSendConfirmWireframe()

        let accountViewModelFactory = AccountViewModelFactory(iconGenerator: UniversalIconGenerator())
        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)

        let dataValidatingFactory = SendDataValidatingFactory(presentable: wireframe)

        let viewModelFactory = WalletSendConfirmViewModelFactory(
            amountFormatterFactory: AssetBalanceFormatterFactory(),
            assetInfo: assetInfo
        )

        let presenter = WalletSendConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            accountViewModelFactory: accountViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            walletSendConfirmViewModelFactory: viewModelFactory,
            logger: Logger.shared,
            chainAsset: chainAsset,
            wallet: wallet,
            receiverAddress: receiverAddress,
            amount: amount,
            tip: tip,
            scamInfo: scamInfo
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
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        receiverAddress: String
    ) -> WalletSendConfirmInteractor? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let feeProxy = ExtrinsicFeeProxy()
        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        guard let accountResponse = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let keystore = Keychain()
        let signingWrapper = SigningWrapper(
            keystore: keystore,
            metaId: selectedMetaAccount.metaId,
            accountResponse: accountResponse
        )
        let dependencyContainer = SendDepencyContainer(
            wallet: wallet,
            operationManager: operationManager
        )
        return WalletSendConfirmInteractor(
            selectedMetaAccount: selectedMetaAccount,
            chainAsset: chainAsset,
            receiverAddress: receiverAddress,
            feeProxy: feeProxy,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: selectedMetaAccount
            ),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            operationManager: operationManager,
            signingWrapper: signingWrapper,
            dependencyContainer: dependencyContainer,
            wallet: wallet
        )
    }
}
