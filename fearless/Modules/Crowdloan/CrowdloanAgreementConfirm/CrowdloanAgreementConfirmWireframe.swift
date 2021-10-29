import Foundation

final class CrowdloanAgreementConfirmWireframe: CrowdloanAgreementConfirmWireframeProtocol {
    func showMoonbeamAgreementSigned(
        from view: CrowdloanAgreementConfirmViewProtocol?,
        paraId: ParaId,
        remarkExtrinsicHash: String,
        crowdloanName: String
    ) {
        guard let confirmationView = MoonbeamAgreementSignedViewFactory.createView(
            extrinsicHash: remarkExtrinsicHash,
            paraId: paraId,
            crowdloanName: crowdloanName
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmationView.controller, animated: true)
    }
}
