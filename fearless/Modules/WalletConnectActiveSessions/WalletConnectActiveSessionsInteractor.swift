import UIKit
import WalletConnectSign

protocol WalletConnectActiveSessionsInteractorOutput: AnyObject {
    func didReceive(sessions: [Session])
}

final class WalletConnectActiveSessionsInteractor {
    // MARK: - Private properties

    private weak var output: WalletConnectActiveSessionsInteractorOutput?

    private let walletConnectService: WalletConnectService

    init(walletConnectService: WalletConnectService) {
        self.walletConnectService = walletConnectService
    }

    // MARK: - Private methods

    private func getSesstion() {
        let sessions = walletConnectService.getSessions()
        output?.didReceive(sessions: sessions)
    }
}

// MARK: - WalletConnectActiveSessionsInteractorInput

extension WalletConnectActiveSessionsInteractor: WalletConnectActiveSessionsInteractorInput {
    func setup(with output: WalletConnectActiveSessionsInteractorOutput) {
        self.output = output
        getSesstion()
        walletConnectService.set(listener: self)
    }

    func setupConnection(uri: String) throws {
        try walletConnectService.connect(uri: uri)
    }
}

// MARK: - WalletConnectServiceDelegate

extension WalletConnectActiveSessionsInteractor: WalletConnectServiceDelegate {
    func didChange(sessions: [Session]) {
        output?.didReceive(sessions: sessions)
    }
}
