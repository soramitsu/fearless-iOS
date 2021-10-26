import Foundation

final class CrowdloanAgreementWireframe: CrowdloanAgreementWireframeProtocol {
    func showAgreementConfirm(from view: CrowdloanAgreementViewProtocol?, paraId: ParaId) {
        guard let confirmationView = CrowdloanAgreementConfirmViewFactory.createView(paraId: paraId) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmationView.controller, animated: true)
    }
}
