import Foundation
import BigInt
import SSFUtils
import SoraFoundation
import SoraKeystore
import SSFModels

enum SendConfirmTransferCall {
    case transfer(Transfer)
    case xorlessTransfer(XorlessTransfer)

    var amount: BigUInt {
        switch self {
        case let .transfer(transfer):
            return transfer.amount
        case let .xorlessTransfer(xorlessTransfer):
            return xorlessTransfer.amount
        }
    }

    var receiverAddress: String {
        switch self {
        case let .transfer(transfer):
            return transfer.receiver
        case let .xorlessTransfer(xorlessTransfer):
            let bokoloId = xorlessTransfer.additionalData
            return String(data: bokoloId, encoding: .utf8) ?? ""
        }
    }

    var tip: BigUInt? {
        switch self {
        case let .transfer(transfer):
            return transfer.tip
        case .xorlessTransfer:
            return nil
        }
    }
}

enum WalletSendConfirmViewFactory {
    static func createView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        call: SendConfirmTransferCall,
        scamInfo: ScamInfo?,
        feeViewModel: BalanceViewModelProtocol?
    ) -> WalletSendConfirmViewProtocol? {
        guard let interactor = createInteractor(
            wallet: wallet,
            chainAsset: chainAsset,
            call: call
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
            call: call,
            scamInfo: scamInfo,
            feeViewModel: feeViewModel
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
        call: SendConfirmTransferCall
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
            call: call,
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
