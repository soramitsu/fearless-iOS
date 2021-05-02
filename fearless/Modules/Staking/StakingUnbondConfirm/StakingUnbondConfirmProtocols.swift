import Foundation
import SoraFoundation

protocol StakingUnbondConfirmViewProtocol: ControllerBackedProtocol, Localizable {}

protocol StakingUnbondConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol StakingUnbondConfirmInteractorInputProtocol: AnyObject {}

protocol StakingUnbondConfirmInteractorOutputProtocol: AnyObject {}

protocol StakingUnbondConfirmWireframeProtocol: AnyObject {}

protocol StakingUnbondConfirmViewFactoryProtocol {
    static func createView(from amount: Decimal) -> StakingUnbondConfirmViewProtocol?
}
