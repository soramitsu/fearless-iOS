import Foundation

final class CrowdloanAgreementConfirmWireframe: CrowdloanAgreementConfirmWireframeProtocol {
    func showAgreementSigned(
        from view: CrowdloanAgreementConfirmViewProtocol?,
        paraId: ParaId,
        remarkExtrinsicHash: String,
        customFlow: CustomCrowdloanFlow
    ) {
        guard let confirmationView = CrowdloanAgreementSignedViewFactory.createView(
            extrinsicHash: remarkExtrinsicHash,
            paraId: paraId,
            customFlow: customFlow
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmationView.controller, animated: true)
    }
}
