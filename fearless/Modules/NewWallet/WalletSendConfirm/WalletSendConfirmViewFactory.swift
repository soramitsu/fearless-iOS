import Foundation
import BigInt
import SSFUtils
import SoraFoundation
import SoraKeystore
import SSFModels
import RobinHood
import SSFStorageQueryKit

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
            return (try? AddressFactory.address(for: xorlessTransfer.receiver, chainFormat: .substrate(69))) ?? ""
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
        feeViewModel: BalanceViewModelProtocol?,
        selection: SelectedWalletAuthority.Lease? = nil
    ) -> WalletSendConfirmViewProtocol? {
        guard selection?.isCurrent ?? true else { return nil }
        let interactor = createInteractor(
            wallet: wallet,
            chainAsset: chainAsset,
            call: call,
            selection: selection
        )

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
            feeViewModel: feeViewModel,
            localizationManager: LocalizationManager.shared
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
        call: SendConfirmTransferCall,
        selection: SelectedWalletAuthority.Lease?
    ) -> WalletSendConfirmInteractor {
        let operationManager = OperationManagerFacade.sharedManager
        let dependencyContainer = SendDepencyContainer(
            wallet: wallet,
            operationManager: operationManager
        )
        let storagePerformer = SSFStorageQueryKit.StorageRequestPerformerDefault(
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )
        let accountInfoRemoteService = AccountInfoRemoteServiceDefault(
            bitcoinBalanceSync: BitcoinBalanceSync(
                discovery: BitcoinReceiveDiscovery(client: BitcoinFailoverIndexerClient())
            ),
            solanaBalanceSync: SolanaRpcBalanceSync.mainnet,
            storagePerformer: storagePerformer
        )
        return WalletSendConfirmInteractor(
            selectedMetaAccount: wallet,
            chainAsset: chainAsset,
            call: call,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: wallet
            ),
            dependencyContainer: dependencyContainer,
            wallet: wallet,
            accountInfoRemoteService: accountInfoRemoteService,
            selection: selection
        )
    }
}
