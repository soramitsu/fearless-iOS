import Foundation

final class ReferralCrowdloanWireframe: ReferralCrowdloanWireframeProtocol {
    func complete(on view: ReferralCrowdloanViewProtocol?) {
        view?.controller.dismiss(animated: true, completion: nil)
    }
}
