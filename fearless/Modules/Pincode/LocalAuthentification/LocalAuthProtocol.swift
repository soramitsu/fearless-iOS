import Foundation

protocol LocalAuthInteractorInputProtocol: AnyObject {
    var allowManualBiometryAuth: Bool { get }

    func startAuth()
    func process(pin: String)
}

protocol LocalAuthInteractorOutputProtocol: AnyObject {
    func didEnterWrongPincode()
    func didChangeState(from state: LocalAuthInteractor.LocalAuthState)
    func didCompleteAuth()
    func didUnexpectedFail()
}
