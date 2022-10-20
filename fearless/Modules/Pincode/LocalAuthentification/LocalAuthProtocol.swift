import Foundation

protocol LocalAuthInteractorInputProtocol: AnyObject {
    var allowManualBiometryAuth: Bool { get }
    var availableBiometryType: AvailableBiometryType { get }

    func startAuth(with output: LocalAuthInteractorOutputProtocol)
    func process(pin: String)
}

protocol LocalAuthInteractorOutputProtocol: AnyObject {
    func didEnterWrongPincode()
    func didChangeState(to state: LocalAuthInteractor.LocalAuthState)
    func didCompleteAuth()
    func didUnexpectedFail()
}
