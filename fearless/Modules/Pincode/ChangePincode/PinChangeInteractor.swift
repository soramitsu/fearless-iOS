import Foundation
import SoraKeystore

final class PinChangeInteractor {
    weak var presenter: PinSetupInteractorOutputProtocol?
    private(set) var secretManager: SecretStoreManagerProtocol
    private var state = PinSetupInteractor.PinSetupState.waitingPincode
    private var generation: UInt64 = 0

    init(secretManager: SecretStoreManagerProtocol) {
        self.secretManager = secretManager
    }

    private func onMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }
}

extension PinChangeInteractor: PinSetupInteractorInputProtocol {
    func process(pin: String) {
        onMain { [weak self] in
            guard let self = self, self.state == .waitingPincode || self.state == .saveFailed else { return }
            self.generation &+= 1
            let attempt = self.generation
            self.state = .submitingPincode
            self.presenter?.didChangeState(to: self.state)
            PinSaveCoordinator.shared.save(
                pin,
                using: self.secretManager,
                isCurrent: { [weak self, weak output = self.presenter] in
                    guard let self = self, let output = output else { return false }
                    return self.generation == attempt && self.state == .submitingPincode && self.presenter === output
                },
                completion: { [weak self, weak output = self.presenter] saved in
                    self?.onMain { [weak self] in
                        guard let self = self, self.generation == attempt, self.state == .submitingPincode,
                              let output = output, self.presenter === output else { return }
                        self.state = saved ? .submitedPincode : .saveFailed
                        output.didChangeState(to: self.state)
                        if saved {
                            output.didSavePin()
                        }
                    }
                }
            )
        }
    }

    func cancel() {
        onMain { [weak self] in
            guard let self = self else { return }
            self.generation &+= 1
            self.state = .cancelled
            self.presenter = nil
        }
    }
}
