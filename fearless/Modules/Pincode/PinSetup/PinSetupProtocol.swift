import UIKit

protocol PinSetupViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didRequestBiometryUsage(
        biometryType: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void
    )

    func didChangeAccessoryState(enabled: Bool, availableBiometryType: AvailableBiometryType)

    func didFailSavingPin()

    func didReceiveWrongPincode()
    func resetAuthenticationInput()
}

protocol PinSetupPresenterProtocol: AnyObject {
    func didLoad(view: PinSetupViewProtocol)
    func cancel()
    func activateBiometricAuth()
    func submit(pin: String)
    func willLeaveView()
    func didLeaveView()
    func didCancelLeavingView()
}

protocol PinSetupInteractorInputProtocol: AnyObject {
    func cancel()
    func process(pin: String)
}

protocol PinSetupInteractorOutputProtocol: AnyObject {
    func didSavePin()
    func didStartWaitingBiometryDecision(
        type: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void
    )
    func didChangeState(to state: PinSetupInteractor.PinSetupState)
}

protocol PinSetupWireframeProtocol: AnyObject {
    func showMain(from view: PinSetupViewProtocol?)
    func showSignup(from view: PinSetupViewProtocol?)
}

protocol PinViewFactoryProtocol: AnyObject {
    static func createPinSetupView() -> PinSetupViewProtocol?
    static func createPinChangeView() -> PinSetupViewProtocol?
    static func createSecuredPinView() -> PinSetupViewProtocol?
    static func createScreenAuthorizationView(with wireframe: ScreenAuthorizationWireframeProtocol, cancellable: Bool)
        -> PinSetupViewProtocol?
    static func createPinCheckView() -> PinSetupViewProtocol?
}

extension PinSetupViewProtocol {
    func resetAuthenticationInput() {}
}

extension PinSetupPresenterProtocol {
    func willLeaveView() {}
    func didLeaveView() {}
    func didCancelLeavingView() {}
}
