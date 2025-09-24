import UIKit
import SoraFoundation
import RobinHood
import SSFUtils
import SSFModels

enum BalanceInfoType {
    case wallet(wallet: MetaAccountModel)
    case chainAsset(wallet: MetaAccountModel, chainAsset: ChainAsset)
    case chainAssets(chainAssets: [ChainAsset], wallet: MetaAccountModel)
    case networkManagement(wallet: MetaAccountModel)

    var wallet: MetaAccountModel {
        switch self {
        case let .wallet(wallet):
            return wallet
        case let .chainAsset(wallet, _):
            return wallet
        case let .chainAssets(_, wallet):
            return wallet
        case let .networkManagement(wallet):
            return wallet
        }
    }
}

enum BalanceInfoAssembly {
    static func configureModule(with type: BalanceInfoType) -> BalanceInfoModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let logger = Logger.shared
        let operationManager = OperationManagerFacade.sharedManager

        let walletBalanceSubscriptionAdapter = WalletBalanceSubscriptionAdapter.shared

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let interactor = BalanceInfoInteractor(
            balanceInfoType: type,
            walletBalanceSubscriptionAdapter: walletBalanceSubscriptionAdapter,
            operationManager: operationManager,
            storageRequestFactory: storageRequestFactory
        )

        let router = BalanceInfoRouter()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let balanceInfoViewModelFactory = BalanceInfoViewModelFactory(
            assetBalanceFormatterFactory: assetBalanceFormatterFactory
        )

        let presenter = BalanceInfoPresenter(
            balanceInfoViewModelFactoryProtocol: balanceInfoViewModelFactory,
            interactor: interactor,
            router: router,
            logger: logger,
            localizationManager: localizationManager,
            eventCenter: EventCenter.shared
        )

        let view = BalanceInfoViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
