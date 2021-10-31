import Foundation
import SoraFoundation
import SoraKeystore

struct CrowdloanAgreementViewFactory {
    static func createView(
        for paraId: ParaId,
        customFlow: CustomCrowdloanFlow
    ) -> CrowdloanAgreementViewProtocol? {
        let localizationManager = LocalizationManager.shared

        guard let interactor = CrowdloanAgreementViewFactory.createInteractor(
            paraId: paraId,
            customFlow: customFlow
        ) else {
            return nil
        }
        let wireframe = CrowdloanAgreementWireframe()

        let presenter = CrowdloanAgreementPresenter(
            interactor: interactor,
            wireframe: wireframe,
            paraId: paraId,
            logger: Logger.shared,
            customFlow: customFlow
        )

        let view = CrowdloanAgreementViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

extension CrowdloanAgreementViewFactory {
    static func createInteractor(
        paraId _: ParaId,
        customFlow: CustomCrowdloanFlow
    ) -> CrowdloanAgreementInteractor? {
        let settings = SettingsManager.shared

        var requestBuilder: HTTPRequestBuilderProtocol?

        switch customFlow {
        case let .moonbeam(moonbeamFlowData):
            requestBuilder = HTTPRequestBuilder(host: moonbeamFlowData.devApiUrl)
        default: break
        }

        guard
            let selectedAddress = settings.selectedAccount?.address,
            let requestBuilder = requestBuilder
        else {
            return nil
        }

        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            settings: settings
        )

        let agreementService = MoonbeamService(
            address: selectedAddress,
            chain: settings.selectedConnection.type.chain,
            signingWrapper: signingWrapper,
            operationManager: OperationManagerFacade.sharedManager,
            requestBuilder: requestBuilder,
            dataOperationFactory: DataOperationFactory()
        )

        return CrowdloanAgreementInteractor(
            agreementService: agreementService,
            signingWrapper: signingWrapper,
            customFlow: customFlow
        )
    }
}
