import UIKit
import SSFUtils
import SoraFoundation
import SSFModels

final class TransferAssembly {
    @MainActor static func configureModule(
        wallet: MetaAccountModel,
        initialData: SendFlowInitialData
    ) -> TransferModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let deps = TransferDepsContainer(wallet: wallet)
        let interactor = TransferInteractor(
            deps: deps,
            chainAssetFetching: ServiceAssembly.shared.chainAssetFetching(qualityOfService: .default),
            scamRepository: ServiceAssembly.shared.scamInfoAsyncRepository()
        )
        let router = TransferRouter()
        let dataValidatingFactory = SendDataValidatingFactory(presentable: router)
        let possibleFlows = Self.createFlows(
            wallet: wallet,
            interactor: interactor,
            dataValidatingFactory: dataValidatingFactory
        )
        let viewModelFactory = SendViewModelFactory(wallet: wallet, iconGenerator: UniversalIconGenerator())
        let presenter = TransferPresenter(
            wallet: wallet,
            initialData: initialData,
            viewModelFactory: viewModelFactory,
            possibleFlows: possibleFlows,
            interactor: interactor,
            router: router,
            logger: ServiceAssembly.shared.logger,
            localizationManager: localizationManager
        )

        let view = TransferViewController(
            initialData: initialData,
            output: presenter,
            localizationManager: localizationManager
        )
        dataValidatingFactory.view = view

        return (view, presenter)
    }

    private static func createFlows(
        wallet: MetaAccountModel,
        interactor: TransferInteractorInput,
        dataValidatingFactory: SendDataValidatingFactory
    ) -> [TransferFlowUseCase] {
        [
            SoraQrTransferFlowUseCase(
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                interactor: interactor,
                logger: ServiceAssembly.shared.logger
            ),
            BokoloTransferFlowUseCase(
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                interactor: interactor,
                logger: ServiceAssembly.shared.logger
            ),
            SubstrateTransferFlowUseCase(
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                interactor: interactor,
                logger: ServiceAssembly.shared.logger
            ),
            EthereumTransferFlowUseCase(
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                interactor: interactor,
                logger: ServiceAssembly.shared.logger
            ),
            TonTransferFlowUseCase(
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                interactor: interactor,
                logger: ServiceAssembly.shared.logger
            )
        ]
    }
}
