import UIKit

final class ScanQRInteractor {
    // MARK: - Private properties

    private weak var output: ScanQRInteractorOutput?
}

// MARK: - ScanQRInteractorInput

extension ScanQRInteractor: ScanQRInteractorInput {
    func setup(with output: ScanQRInteractorOutput) {
        self.output = output
    }
}
