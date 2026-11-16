import XCTest
import UIKit
import SoraFoundation
import SoraKeystore
import SoraUI
@testable import fearless

final class CovJOnPinView: UIViewController, PinSetupViewProtocol {
    var events: [String] = []
    var lockouts: [TimeInterval] = []
    var biometryRequests: [AvailableBiometryType] = []
    func didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock _: @escaping (Bool) -> Void) {
        biometryRequests.append(biometryType)
    }
    func didChangeAccessoryState(enabled: Bool, availableBiometryType _: AvailableBiometryType) { events.append("accessory:\(enabled)") }
    func didFailSavingPin() { events.append("saveFailed") }
    func didReceiveWrongPincode() { events.append("wrong") }
    func didReceiveLockout(remaining: TimeInterval) { lockouts.append(remaining) }
    func didStartLoading() { events.append("start") }
    func didStopLoading() { events.append("stop") }
}

/// Relies on the protocol's default lockout and reset handlers.
final class CovJOnPlainPinView: UIViewController, PinSetupViewProtocol {
    var events: [String] = []
    func didRequestBiometryUsage(biometryType _: AvailableBiometryType, completionBlock _: @escaping (Bool) -> Void) {}
    func didChangeAccessoryState(enabled _: Bool, availableBiometryType _: AvailableBiometryType) {}
    func didFailSavingPin() {}
    func didReceiveWrongPincode() { events.append("wrong") }
    func didStartLoading() { events.append("start") }
    func didStopLoading() { events.append("stop") }
}

final class CovJOnLocalAuthInteractor: LocalAuthInteractorInputProtocol {
    var allowManualBiometryAuth = true
    var availableBiometryType: AvailableBiometryType = .faceId
    var starts = 0
    var cancels = 0
    var pins: [String] = []
    func startAuth(with _: LocalAuthInteractorOutputProtocol) { starts += 1 }
    func process(pin: String) { pins.append(pin) }
    func cancelAuth() { cancels += 1 }
}

final class CovJOnPinWireframe: PinSetupWireframeProtocol {
    var mains = 0
    var signups = 0
    func showMain(from _: PinSetupViewProtocol?) { mains += 1 }
    func showSignup(from _: PinSetupViewProtocol?) { signups += 1 }
}

final class CovJOnCheckOutput: CheckPincodeModuleOutput {
    var checks = 0
    var closes = 0
    func didCheck() { checks += 1 }
    func close(view _: ControllerBackedProtocol?) { closes += 1 }
}

final class CovJOnPinSetupInteractor: PinSetupInteractorInputProtocol {
    var cancels = 0
    var pins: [String] = []
    func cancel() { cancels += 1 }
    func process(pin: String) { pins.append(pin) }
}

final class CovJOnScreenAuthWireframe: ScreenAuthorizationWireframeProtocol {
    var results: [Bool] = []
    func showAuthorizationCompletion(with result: Bool) { results.append(result) }
}

final class CovJOnPinPresenterSpy: PinSetupPresenterProtocol {
    var events: [String] = []
    func didLoad(view _: PinSetupViewProtocol) { events.append("load") }
    func cancel() { events.append("cancel") }
    func activateBiometricAuth() { events.append("biometry") }
    func submit(pin: String) { events.append("pin:" + pin) }
}

final class CovJOnPinPresenterLogicTests: XCTestCase {
    func testLocalAuthPresenterForwardsInputsAndDeliversResultsOnMain() {
        let interactor = CovJOnLocalAuthInteractor()
        let wireframe = CovJOnPinWireframe()
        let presenter = LocalAuthPresenter(wireframe: wireframe, interactor: interactor)
        let view = CovJOnPinView()
        presenter.didLoad(view: view)
        XCTAssertEqual(view.events, ["accessory:true"])
        XCTAssertEqual(interactor.starts, 1)
        presenter.cancel()
        presenter.activateBiometricAuth()
        presenter.submit(pin: "1234")
        presenter.willLeaveView()
        presenter.didLeaveView()
        presenter.didCancelLeavingView()
        XCTAssertEqual(interactor.starts, 2)
        XCTAssertEqual(interactor.pins, ["1234"])

        presenter.didChangeState(to: .checkingPincode)
        XCTAssertEqual(view.events, ["accessory:true"])
        presenter.didChangeState(to: .completed)
        XCTAssertEqual(view.events.last, "start")

        presenter.didEnterWrongPincode()
        presenter.didReceiveLockout(remaining: 30)
        presenter.didCompleteAuth()
        presenter.didUnexpectedFail()
        XCTAssertTrue(CovJWait.until { wireframe.signups == 1 })
        XCTAssertEqual(Array(view.events.suffix(3)), ["stop", "wrong", "stop"])
        XCTAssertEqual(view.lockouts, [30])
        XCTAssertEqual(wireframe.mains, 1)
    }

    func testLocalAuthLockoutFallsBackToTheDefaultViewHandler() {
        let presenter = LocalAuthPresenter(wireframe: CovJOnPinWireframe(), interactor: CovJOnLocalAuthInteractor())
        let view = CovJOnPlainPinView()
        presenter.didLoad(view: view)
        presenter.didReceiveLockout(remaining: 5)
        XCTAssertTrue(CovJWait.until { view.events == ["stop"] })
        view.resetAuthenticationInput()
        XCTAssertEqual(view.events, ["stop"])
    }

    func testCheckPincodePresenterStopsDeliveringOnceFinished() {
        let interactor = CovJOnLocalAuthInteractor()
        let output = CovJOnCheckOutput()
        let presenter = CheckPincodePresenter(interactor: interactor, moduleOutput: output)
        let view = CovJOnPinView()
        presenter.didLoad(view: view)
        presenter.activateBiometricAuth()
        presenter.submit(pin: "0000")
        presenter.didChangeState(to: .checkingBiometry)
        presenter.didUnexpectedFail()
        presenter.didEnterWrongPincode()
        presenter.didReceiveLockout(remaining: 12)
        XCTAssertTrue(CovJWait.until { view.lockouts == [12] })
        XCTAssertEqual(view.events, ["accessory:true", "wrong"])
        XCTAssertEqual(interactor.starts, 2)
        XCTAssertEqual(interactor.pins, ["0000"])

        presenter.cancel()
        presenter.cancel()
        XCTAssertEqual(output.closes, 1)
        XCTAssertEqual(interactor.cancels, 1)
        presenter.activateBiometricAuth()
        presenter.submit(pin: "1111")
        presenter.didEnterWrongPincode()
        presenter.didReceiveLockout(remaining: 3)
        presenter.didCompleteAuth()
        CovJWait.drain(0.1)
        XCTAssertEqual(interactor.starts, 2)
        XCTAssertEqual(interactor.pins, ["0000"])
        XCTAssertEqual(view.lockouts, [12])
        XCTAssertEqual(output.checks, 0)
    }

    func testPinSetupPresenterAsksAboutBiometryUntilCompleted() {
        let interactor = CovJOnPinSetupInteractor()
        let wireframe = CovJOnPinWireframe()
        let view = CovJOnPinView()
        var presenter: PinSetupPresenter? = PinSetupPresenter(interactor: interactor, wireframe: wireframe)
        presenter?.didLoad(view: view)
        presenter?.activateBiometricAuth()
        presenter?.didStartWaitingBiometryDecision(type: .touchId) { _ in }
        XCTAssertTrue(CovJWait.until { view.biometryRequests == [.touchId] })
        presenter?.cancel()
        presenter?.didStartWaitingBiometryDecision(type: .faceId) { _ in }
        CovJWait.drain(0.1)
        XCTAssertEqual(view.biometryRequests, [.touchId])
        XCTAssertEqual(interactor.cancels, 1)
        presenter = nil
        XCTAssertEqual(interactor.cancels, 2, "Releasing the presenter cancels the interactor")
    }

    func testScreenAuthorizationRestartsBiometryAndFailsOnUnexpectedError() {
        let interactor = CovJOnLocalAuthInteractor()
        let wireframe = CovJOnScreenAuthWireframe()
        let presenter = ScreenAuthorizationPresenter(wireframe: wireframe, interactor: interactor)
        let view = CovJOnPinView()
        presenter.didLoad(view: view)
        presenter.activateBiometricAuth()
        XCTAssertEqual(interactor.starts, 2)
        presenter.didUnexpectedFail()
        XCTAssertTrue(CovJWait.until { wireframe.results == [false] })
        presenter.activateBiometricAuth()
        XCTAssertEqual(interactor.starts, 2)
    }
}

final class CovJOnCheckPincodeControllerTests: XCTestCase {
    private func dismissPresented(_ controller: UIViewController) {
        controller.presentedViewController?.dismiss(animated: false)
        CovJWait.until { controller.presentedViewController == nil }
    }

    func testInputsReachThePresenterAndAccessoryFollowsBiometry() throws {
        let presenter = CovJOnPinPresenterSpy()
        let controller = CheckPincodeViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = controller.rootView
        XCTAssertEqual(presenter.events, ["load"])
        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        controller.didChangeAccessoryState(enabled: true, availableBiometryType: .faceId)
        XCTAssertEqual(root.pinView.numpadView?.supportsAccessoryControl, true)
        XCTAssertNotNil(root.pinView.numpadView?.accessoryIcon)
        controller.didChangeAccessoryState(enabled: false, availableBiometryType: .none)
        XCTAssertEqual(root.pinView.numpadView?.supportsAccessoryControl, false)
        XCTAssertNil(root.pinView.numpadView?.accessoryIcon)
        controller.didSelectAccessoryControl(pinView: root.pinView)
        controller.didCompleteInput(pinView: root.pinView, result: "123456")
        controller.didChange(pinView: root.pinView, from: .normal)
        controller.didFailConfirmation(pinView: root.pinView)
        controller.didReceiveWrongPincode()
        XCTAssertEqual(presenter.events, ["load", "cancel", "biometry", "pin:123456"])
    }

    func testLockoutBlocksInputUntilTheCountdownEnds() throws {
        let presenter = CovJOnPinPresenterSpy()
        let controller = CheckPincodeViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = controller.rootView
        controller.didReceiveLockout(remaining: 0)
        XCTAssertNil(root.lockoutRemaining)
        controller.didReceiveLockout(remaining: 1)
        XCTAssertNotNil(root.lockoutRemaining)
        controller.didCompleteInput(pinView: root.pinView, result: "999999")
        XCTAssertEqual(presenter.events, ["load"], "No PIN is submitted during a lockout")
        XCTAssertTrue(CovJWait.until(timeout: 4) { root.lockoutRemaining == nil })
        XCTAssertEqual(root.titleLabel.text, R.string.localizable.pincodeEnterPinCode(preferredLanguages: root.locale.rLanguages))
        controller.didCompleteInput(pinView: root.pinView, result: "999999")
        XCTAssertEqual(presenter.events, ["load", "pin:999999"])
    }

    func testAlertsExplainSaveFailuresAndAskAboutBiometry() throws {
        let controller = CheckPincodeViewController(presenter: CovJOnPinPresenterSpy(), localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer {
            dismissPresented(controller)
            window.isHidden = true
        }
        let languages = controller.localizationManager?.selectedLocale.rLanguages
        controller.didFailSavingPin()
        var alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages))
        XCTAssertEqual(alert.message, R.string.localizable.pincodeSaveFailed(preferredLanguages: languages))
        XCTAssertEqual(alert.actions.map(\.title), [R.string.localizable.commonOk(preferredLanguages: languages)])
        dismissPresented(controller)

        var decisions: [Bool] = []
        controller.didRequestBiometryUsage(biometryType: .none) { decisions.append($0) }
        XCTAssertEqual(decisions, [true])
        XCTAssertNil(controller.presentedViewController)

        controller.didRequestBiometryUsage(biometryType: .touchId) { decisions.append($0) }
        alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, R.string.localizable.askTouchidTitle(preferredLanguages: languages))
        XCTAssertEqual(alert.actions.map(\.title), [
            R.string.localizable.commonUse(preferredLanguages: languages),
            R.string.localizable.commonSkip(preferredLanguages: languages)
        ])
        dismissPresented(controller)

        controller.didRequestBiometryUsage(biometryType: .faceId) { decisions.append($0) }
        alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, R.string.localizable.askFaceidTitle(preferredLanguages: languages))
        XCTAssertEqual(alert.message, R.string.localizable.askFaceidMessage(preferredLanguages: languages))
        XCTAssertEqual(decisions, [true])
    }
}

final class CovJOnPinSetupControllerTests: XCTestCase {
    private func make(mode: PinView.Mode) -> (PinSetupViewController, CovJOnPinPresenterSpy) {
        let controller = PinSetupViewController(nib: R.nib.pinSetupViewController)
        let presenter = CovJOnPinPresenterSpy()
        controller.presenter = presenter
        controller.mode = mode
        controller.localizationManager = LocalizationManager.shared
        return (controller, presenter)
    }

    func testFlightTiersAndBiometryPrompts() throws {
        let (controller, presenter) = make(mode: .securedInput)
        XCTAssertTrue(controller.flightTiers.isEmpty, "Nothing flies before the view exists")
        let window = try CovJViewFixture.host(controller)
        defer {
            controller.presentedViewController?.dismiss(animated: false)
            window.isHidden = true
        }
        XCTAssertEqual(presenter.events, ["load"])
        let tiers = controller.flightTiers
        XCTAssertEqual(tiers.count, 5)
        XCTAssertEqual(tiers.map(\.tier), [0, 1, 2, 2, 2])
        controller.resetAuthenticationInput()

        let languages = controller.localizationManager?.selectedLocale.rLanguages
        var decisions: [Bool] = []
        controller.didRequestBiometryUsage(biometryType: .none) { decisions.append($0) }
        XCTAssertEqual(decisions, [true])
        controller.didRequestBiometryUsage(biometryType: .faceId) { decisions.append($0) }
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, R.string.localizable.askFaceidTitle(preferredLanguages: languages))
        XCTAssertEqual(alert.actions.count, 2)
        alert.dismiss(animated: false)
        XCTAssertTrue(CovJWait.until { controller.presentedViewController == nil })
        controller.didRequestBiometryUsage(biometryType: .touchId) { decisions.append($0) }
        let touch = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(touch.message, R.string.localizable.askTouchidMessage(preferredLanguages: languages))
    }

    func testLeavingConfirmationStepPopsTheConfirmationItem() throws {
        let (controller, presenter) = make(mode: .create)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let pinView = try XCTUnwrap(CovJViewFixture.descendants(PinView.self, in: controller.view).first)
        controller.didChange(pinView: pinView, from: .confirm)
        controller.didSelectAccessoryControl(pinView: pinView)
        controller.didFailConfirmation(pinView: pinView)
        controller.didCompleteInput(pinView: pinView, result: "2580")
        XCTAssertEqual(presenter.events, ["load", "biometry", "pin:2580"])
    }
}

final class CovJOnPinFactoriesTests: XCTestCase {
    func testFactoriesBuildScreensWithoutLoadingThem() throws {
        let check = try XCTUnwrap(PinViewFactory.createPinCheckView()?.controller as? PinSetupViewController)
        XCTAssertEqual(check.mode, .securedInput)
        XCTAssertEqual(check.modalPresentationStyle, .fullScreen)
        XCTAssertTrue(check.presenter is LocalAuthPresenter)
        XCTAssertFalse(check.isViewLoaded)

        let setup = try XCTUnwrap(PinViewFactory.createPinSetupView(keystore: InMemoryKeychain())?.controller as? PinSetupViewController)
        XCTAssertEqual(setup.mode, .create)
        XCTAssertEqual(
            setup.localizableTopTitle.value(for: CovJFixture.locale),
            R.string.localizable.pincodeSetupTopTitle(preferredLanguages: CovJFixture.locale.rLanguages)
        )
        XCTAssertNotNil(PinViewFactory.createPinSetupView())
    }
}

final class CovJOnPinWireframeTests: XCTestCase {
    func testCheckWireframeUnlocksAfterDismissingThePresentedCheck() throws {
        let center = NotificationCenter()
        let lockState = ApplicationLockState(notificationCenter: center)
        let host = UIViewController()
        let window = try CovJViewFixture.host(host)
        defer { window.isHidden = true }
        let check = CovJOnPinView()
        host.present(check, animated: false)
        lockState.lock(with: check)
        XCTAssertTrue(lockState.isLocked)

        let wireframe = CheckPincodeWireframe(lockState: lockState)
        let animator = CovJOnRootAnimatorSpy()
        wireframe.rootAnimator = animator
        wireframe.showSignup(from: check)
        let installed: KeystoreImportServiceProtocol? = URLHandlingService.shared.findService()
        XCTAssertEqual(animator.controllers.isEmpty, installed == nil)
        wireframe.showMain(from: check)
        XCTAssertTrue(CovJWait.until(timeout: 3) { !lockState.isLocked })
        XCTAssertNil(host.presentedViewController)
    }

    func testSetupWireframeNeedsTheOnboardingScreenToShowSignup() {
        let wireframe = PinSetupWireframe()
        let animator = CovJOnRootAnimatorSpy()
        wireframe.rootAnimator = animator
        wireframe.showSignup(from: nil)
        let installed: KeystoreImportServiceProtocol? = URLHandlingService.shared.findService()
        XCTAssertEqual(animator.controllers.isEmpty, installed == nil)
    }

    func testChangeWireframeConfirmsThenReturnsToTheRoot() throws {
        let root = UIViewController()
        let navigation = UINavigationController(rootViewController: root)
        let window = try CovJViewFixture.host(navigation)
        defer {
            navigation.presentedViewController?.dismiss(animated: false)
            window.isHidden = true
        }
        let pin = CovJOnPinView()
        navigation.pushViewController(pin, animated: false)
        let wireframe = PinChangeWireframe(localizationManager: LocalizationManager.shared)
        wireframe.showStories()
        let installed: KeystoreImportServiceProtocol? = URLHandlingService.shared.findService()
        XCTAssertNil(installed, "Unit-test launches install no URL handlers")
        if installed == nil {
            // Without the onboarding screen the wireframe stops before touching the root window.
            wireframe.showSignup(from: pin)
        }
        XCTAssertEqual(navigation.viewControllers.count, 2)
        wireframe.showMain(from: pin)
        XCTAssertNotNil(pin.presentedViewController ?? navigation.presentedViewController)
        XCTAssertTrue(CovJWait.until(timeout: 5) { navigation.viewControllers.count == 1 })
    }
}
