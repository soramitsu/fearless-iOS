import UIKit
import SoraFoundation

import SSFModels

final class SwapTransactionDetailAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        transaction: AssetTransactionData
    ) -> SwapTransactionDetailModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared

        let interactor = SwapTransactionDetailInteractor(
            chainAsset: chainAsset,
            priceLocalSubscriber: priceLocalSubscriber,
            logger: Logger.shared
        )
        let router = SwapTransactionDetailRouter()

        let presenter = SwapTransactionDetailPresenter(
            wallet: wallet,
            chainAsset: chainAsset,
            transaction: transaction,
            viewModelFactory: SwapTransactionViewModelFactory(),
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = SwapTransactionDetailViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
