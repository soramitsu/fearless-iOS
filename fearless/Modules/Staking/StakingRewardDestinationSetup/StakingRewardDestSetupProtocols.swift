import Foundation
import SoraFoundation

protocol StakingRewardDestSetupViewProtocol: ControllerBackedProtocol, Localizable {
    #warning("Not implemented")
}

protocol StakingRewardDestSetupPresenterProtocol: AnyObject {
    func setup()
    func selectRestakeDestination()
    func selectPayoutDestination()
    func selectPayoutAccount()
    func displayLearnMore()
    func proceed()
}

protocol StakingRewardDestSetupInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingRewardDestSetupInteractorOutputProtocol: AnyObject {
    #warning("Not implemented")
}

protocol StakingRewardDestSetupWireframeProtocol: WebPresentable, AlertPresentable, ErrorPresentable,
    StakingErrorPresentable {
    func proceed(view: StakingRewardDestSetupViewProtocol?)
}

protocol StakingRewardDestSetupViewFactoryProtocol {
    static func createView() -> StakingRewardDestSetupViewProtocol?
}
