import UIKit
import SSFModels
import SoraFoundation

final class ConfirmTransferAssembly {
    @MainActor
    static func configureModule(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        useCase: TransferFlowUseCase,
        sendFlow: SendFlowInitialData,
        scamInfo: ScamInfo?
    ) -> ConfirmTransferModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let deps = TransferDepsContainer(wallet: wallet)
        let interactor = TransferInteractor(
            deps: deps,
            chainAssetFetching: ServiceAssembly.shared.chainAssetFetching(qualityOfService: .default),
            scamRepository: ServiceAssembly.shared.scamInfoAsyncRepository()
        )
        let router = ConfirmTransferRouter()

        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let viewModelFactory = WalletSendConfirmViewModelFactory(
            wallet: wallet,
            amountFormatterFactory: AssetBalanceFormatterFactory(),
            assetInfo: assetInfo
        )

        let presenter = ConfirmTransferPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: viewModelFactory,
            useCase: useCase,
            sendFlow: sendFlow,
            scamInfo: scamInfo,
            logger: ServiceAssembly.shared.logger,
            localizationManager: localizationManager
        )

        let view = ConfirmTransferViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
