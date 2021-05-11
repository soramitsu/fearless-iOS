import Foundation
import SoraFoundation

protocol StakingRewardDestSetupViewProtocol: ControllerBackedProtocol, Localizable {
    #warning("Not implemented")
}

protocol StakingRewardDestSetupPresenterProtocol: AnyObject {
    func setup()
}

protocol StakingRewardDestSetupInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingRewardDestSetupInteractorOutputProtocol: AnyObject {
    #warning("Not implemented")
}

protocol StakingRewardDestSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable {
    func close(view: StakingRewardDestSetupViewProtocol?)
    func proceed(view: StakingRewardDestSetupViewProtocol?)
}

protocol StakingRewardDestSetupViewFactoryProtocol {
    static func createView() -> StakingRewardDestSetupViewProtocol?
}
