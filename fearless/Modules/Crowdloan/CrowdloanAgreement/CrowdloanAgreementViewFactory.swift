import Foundation
import SoraFoundation
import SoraKeystore

struct CrowdloanAgreementViewFactory {
    static func createMoonbeamView(
        for paraId: ParaId,
        crowdloanName: String,
        moonbeamFlowData: MoonbeamFlowData
    ) -> CrowdloanAgreementViewProtocol? {
        let localizationManager = LocalizationManager.shared

        guard let interactor = CrowdloanAgreementViewFactory.createMoonbeamInteractor(
            paraId: paraId,
            moonbeamFlowData: moonbeamFlowData
        ) else {
            return nil
        }
        let wireframe = CrowdloanAgreementWireframe()

        let presenter = CrowdloanAgreementPresenter(
            interactor: interactor,
            wireframe: wireframe,
            paraId: paraId,
            crowdloanTitle: crowdloanName
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
        moonbeamFlowData: MoonbeamFlowData
    ) -> CrowdloanAgreementInteractor? {
        let settings = SettingsManager.shared

        guard let selectedAddress = settings.selectedAccount?.address else {
            return nil
        }

        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            settings: settings
        )

        let requestBuilder: HTTPRequestBuilderProtocol = HTTPRequestBuilder(host: moonbeamFlowData.devApiUrl)

        let agreementService = MoonbeamService(
            address: selectedAddress,
            chain: settings.selectedConnection.type.chain,
            signingWrapper: signingWrapper,
            operationManager: OperationManagerFacade.sharedManager,
            requestBuilder: requestBuilder
        )
        return CrowdloanAgreementInteractor(agreementService: agreementService)
    }
}
