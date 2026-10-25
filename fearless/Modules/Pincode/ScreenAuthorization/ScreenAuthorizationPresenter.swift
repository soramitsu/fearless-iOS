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
        ) { [weak self] _ in self?.cancel() }
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
        finish(with: false)
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
        finish(with: false)
    }

    func didCancelLeavingView() {
        guard !finished, departurePending else { return }
        departurePending = false
        view?.resetAuthenticationInput()
        interactor.startAuth(with: self)
    }

    private func finish(with result: Bool) {
        guard !finished, !result || !departurePending else { return }
        finished = true
        deliveryGeneration &+= 1
        interactor.cancelAuth()
        wireframe.showAuthorizationCompletion(with: result)
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

    func didChangeState(to _: LocalAuthInteractor.LocalAuthState) {}

    func didCompleteAuth() {
        let generation = deliveryGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.deliveryGeneration == generation else { return }
            self.finish(with: true)
        }
    }

    func didUnexpectedFail() {
        let generation = deliveryGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.deliveryGeneration == generation else { return }
            self.finish(with: false)
        }
    }
}
