import Foundation
import SoraKeystore

struct CrowdloanContributionSetupViewFactory {
    static func createView(for paraId: ParaId) -> CrowdloanContributionSetupViewProtocol? {
        guard let interactor = createInteractor(for: paraId) else {
            return nil
        }

        let wireframe = CrowdloanContributionSetupWireframe()

        let presenter = CrowdloanContributionSetupPresenter(interactor: interactor, wireframe: wireframe)

        let view = CrowdloanContributionSetupViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(for paraId: ParaId) -> CrowdloanContributionSetupInteractor? {
        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        let settings = SettingsManager.shared

        guard let selectedAccount = settings.selectedAccount else {
            return nil
        }

        let chain = settings.selectedConnection.type.chain

        let operationManager = OperationManagerFacade.sharedManager

        let runtimeService = RuntimeRegistryFacade.sharedService

        let extrinsicService = ExtrinsicService(
            address: selectedAccount.address,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let feeProxy = ExtrinsicFeeProxy()

        let singleValueProviderFactory = SingleValueProviderFactory.shared

        return CrowdloanContributionSetupInteractor(
            paraId: paraId,
            selectedAccountAddress: selectedAccount.address,
            chain: chain,
            connection: connection,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            singleValueProviderFactory: singleValueProviderFactory,
            operationManager: operationManager
        )
    }
}
