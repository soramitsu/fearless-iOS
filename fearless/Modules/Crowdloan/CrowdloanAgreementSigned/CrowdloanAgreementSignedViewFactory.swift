import Foundation

struct CrowdloanAgreementSignedViewFactory {
    static func createView(
        extrinsicHash: String,
        paraId: ParaId,
        customFlow: CustomCrowdloanFlow
    ) -> CrowdloanAgreementSignedViewProtocol? {
        let interactor = CrowdloanAgreementSignedInteractor()
        let wireframe = CrowdloanAgreementSignedWireframe()

        let presenter = CrowdloanAgreementSignedPresenter(
            interactor: interactor,
            wireframe: wireframe,
            extrinsicHash: extrinsicHash,
            paraId: paraId,
            customFlow: customFlow
        )

        let view = CrowdloanAgreementSignedViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
