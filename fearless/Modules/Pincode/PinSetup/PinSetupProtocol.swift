import UIKit

protocol PinSetupViewProtocol: ControllerBackedProtocol {
    func didRequestBiometryUsage(
        biometryType: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void)

    func didChangeAccessoryState(enabled: Bool)

    func didReceiveWrongPincode()
}

protocol PinSetupPresenterProtocol: class {
    func start()
    func cancel()
    func activateBiometricAuth()
    func submit(pin: String)
}

protocol PinSetupInteractorInputProtocol: class {
    func process(pin: String)
}

protocol PinSetupInteractorOutputProtocol: class {
    func didSavePin()
    func didStartWaitingBiometryDecision(
        type: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void)
    func didChangeState(from: PinSetupInteractor.PinSetupState)
}

protocol PinSetupWireframeProtocol: class {
    func showMain(from view: PinSetupViewProtocol?)
    func showSignup(from view: PinSetupViewProtocol?)
}

protocol PinViewFactoryProtocol: class {
    static func createPinSetupView() -> PinSetupViewProtocol?
    static func createPinChangeView() -> PinSetupViewProtocol?
    static func createSecuredPinView() -> PinSetupViewProtocol?
    static func createScreenAuthorizationView(with wireframe: ScreenAuthorizationWireframeProtocol, cancellable: Bool)
        -> PinSetupViewProtocol?
}

enum PinAppearanceAnimationConstants {
    static let type = CATransitionType.moveIn
    static let subtype = CATransitionSubtype.fromTop
    static let timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
    static let duration = 0.3
    static let animationKey = "pin.transitionIn"
}

enum PinDismissAnimationConstants {
    static let type = CATransitionType.fade
    static let timingFunction = CAMediaTimingFunctionName.easeOut
    static let duration = 0.3
    static let animationKey = "pin.transitionOut"
}
