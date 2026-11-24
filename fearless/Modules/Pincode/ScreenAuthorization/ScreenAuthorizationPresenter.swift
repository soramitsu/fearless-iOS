import UIKit

final class ScreenAuthorizationPresenter {
    private weak var view: PinSetupViewProtocol?
    private var wireframe: ScreenAuthorizationWireframeProtocol
    private var interactor: LocalAuthInteractorInputProtocol
    private var finished = false
    private var departurePending = false
    private var deliveryGeneration: UInt64 = 0
    private var backgroundObserver: NSObjectProtocol?

    init(
        wireframe: ScreenAuthorizationWireframeProtocol,
        interactor: LocalAuthInteractorInputProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // The PIN closes with the app, but the user answered nothing: the caller may ask again.
            self?.finish(with: .unanswered)
        }
    }

    deinit {
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
    }
}

extension ScreenAuthorizationPresenter: PinSetupPresenterProtocol {
    func didLoad(view: PinSetupViewProtocol) {
        self.view = view

        self.view?.didChangeAccessoryState(
            enabled: interactor.allowManualBiometryAuth,
            availableBiometryType: interactor.availableBiometryType
        )
        interactor.startAuth(with: self)
    }

    func cancel() {
        finish(with: .declined)
    }

    func willLeaveView() {
        guard !finished else { return }
        departurePending = true
        deliveryGeneration &+= 1
        interactor.cancelAuth()
    }

    func didLeaveView() {
        guard departurePending else { return }
        departurePending = false
        finish(with: .declined)
    }

    func didCancelLeavingView() {
        guard !finished, departurePending else { return }
        departurePending = false
        view?.resetAuthenticationInput()
        interactor.startAuth(with: self)
    }

    /// UIKit marks a dismissal as begun before it calls `viewWillDisappear`, so a reply can land between the two.
    private var isLeavingView: Bool {
        guard let controller = view?.controller else { return false }
        return controller.isMovingFromParent || controller.isBeingDismissed ||
            controller.navigationController?.isBeingDismissed == true
    }

    private func finish(with outcome: ScreenAuthorizationOutcome) {
        guard !finished, !outcome.isAuthorized || !(departurePending || isLeavingView) else { return }
        finished = true
        deliveryGeneration &+= 1
        interactor.cancelAuth()
        wireframe.showAuthorizationCompletion(outcome: outcome)
    }

    func activateBiometricAuth() {
        guard !finished, !departurePending else { return }
        interactor.startAuth(with: self)
    }

    func submit(pin: String) {
        guard !finished, !departurePending else { return }
        interactor.process(pin: pin)
    }
}

extension ScreenAuthorizationPresenter: LocalAuthInteractorOutputProtocol {
    func didEnterWrongPincode() {
        let generation = deliveryGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.deliveryGeneration == generation,
                  !self.finished, !self.departurePending else { return }
            self.view?.didReceiveWrongPincode()
        }
    }

    func didReceiveLockout(remaining: TimeInterval) {
        let generation = deliveryGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.deliveryGeneration == generation,
                  !self.finished, !self.departurePending else { return }
            self.view?.didReceiveLockout(remaining: remaining)
        }
    }

    func didChangeState(to _: LocalAuthInteractor.LocalAuthState) {}

    func didCompleteAuth() {
        let generation = deliveryGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.deliveryGeneration == generation else { return }
            self.finish(with: .authorized)
        }
    }

    func didUnexpectedFail() {
        let generation = deliveryGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.deliveryGeneration == generation else { return }
            self.finish(with: .declined)
        }
    }
}
