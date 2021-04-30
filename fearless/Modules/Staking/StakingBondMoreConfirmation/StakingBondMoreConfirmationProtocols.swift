import SoraFoundation
import CommonWallet
import BigInt

protocol StakingBondMoreConfirmationViewProtocol: ControllerBackedProtocol, Localizable {}

protocol StakingBondMoreConfirmationPresenterProtocol: AnyObject {
    func setup()
}

protocol StakingBondMoreConfirmationInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingBondMoreConfirmationOutputProtocol: AnyObject {}

protocol StakingBondMoreConfirmationWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {}
