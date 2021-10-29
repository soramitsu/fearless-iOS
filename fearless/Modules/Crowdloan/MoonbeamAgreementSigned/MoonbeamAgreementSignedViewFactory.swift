import Foundation

struct MoonbeamAgreementSignedViewFactory {
    static func createView(extrinsicHash: String, paraId: ParaId, crowdloanName: String) -> MoonbeamAgreementSignedViewProtocol? {
        let interactor = MoonbeamAgreementSignedInteractor()
        let wireframe = MoonbeamAgreementSignedWireframe()

        let presenter = MoonbeamAgreementSignedPresenter(
            interactor: interactor,
            wireframe: wireframe,
            extrinsicHash: extrinsicHash,
            paraId: paraId,
            crowdloanName: crowdloanName
        )

        let view = MoonbeamAgreementSignedViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
