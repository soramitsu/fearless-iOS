import Foundation
import SoraFoundation
import SoraKeystore

struct CrowdloanAgreementViewFactory {
    static func createView(
        for paraId: ParaId,
        customFlow: CustomCrowdloanFlow
    ) -> CrowdloanAgreementViewProtocol? {
        switch customFlow {
        case let .moonbeam(moonbeamFlowData):
            return CrowdloanAgreementViewFactory.createMoonbeamView(
                for: paraId,
                customFlow: customFlow,
                moonbeamFlowData: moonbeamFlowData
            )
        default:
            return nil
        }
    }

    private static func createMoonbeamView(
        for paraId: ParaId,
        customFlow: CustomCrowdloanFlow,
        moonbeamFlowData: MoonbeamFlowData
    ) -> CrowdloanAgreementViewProtocol? {
        let localizationManager = LocalizationManager.shared

        guard let interactor = CrowdloanAgreementViewFactory.createMoonbeamInteractor(
            paraId: paraId,
            customFlow: customFlow,
            moonbeamFlowData: moonbeamFlowData
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
    static func createMoonbeamInteractor(
        paraId _: ParaId,
        customFlow: CustomCrowdloanFlow,
        moonbeamFlowData: MoonbeamFlowData
    ) -> CrowdloanAgreementInteractor? {
        let settings = SettingsManager.shared

        guard let selectedAddress = settings.selectedAccount?.address else { return nil }

        let signingWrapper = SigningWrapper(keystore: Keychain(), settings: settings)

        #if F_DEV
            let apiKey = moonbeamFlowData.devApiKey
            let host = moonbeamFlowData.devApiUrl
        #else
            let apiKey = moonbeamFlowData.prodApiKey
            let host = moonbeamFlowData.prodApiUrl
        #endif

        let headerBuilder = MoonbeamHTTPHeadersBuilder(apiKey: apiKey)
        let requestBuilder = HTTPRequestBuilder(host: host, headerBuilder: headerBuilder)

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
