import Foundation

protocol LocalAuthInteractorInputProtocol: AnyObject {
    var allowManualBiometryAuth: Bool { get }
    var availableBiometryType: AvailableBiometryType { get }

    func startAuth(with output: LocalAuthInteractorOutputProtocol)
    func process(pin: String)
    func cancelAuth()
}

protocol LocalAuthInteractorOutputProtocol: AnyObject {
    func didEnterWrongPincode()
    /// Too many wrong PINs: no PIN is checked for `remaining` seconds.
    func didReceiveLockout(remaining: TimeInterval)
    func didChangeState(to state: LocalAuthInteractor.LocalAuthState)
    func didCompleteAuth()
    func didUnexpectedFail()
}

extension LocalAuthInteractorOutputProtocol {
    func didReceiveLockout(remaining _: TimeInterval) {}
}
