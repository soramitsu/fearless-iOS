import UIKit
import WalletConnectSign
import SSFModels
import RobinHood

protocol WalletConnectActiveSessionsInteractorOutput: AnyObject {
    func didReceive(sessions: [Session])
    func didReceive(connectedApps: [TonConnectApp])
}

final class WalletConnectActiveSessionsInteractor {
    // MARK: - Private properties

    private weak var output: WalletConnectActiveSessionsInteractorOutput?

    private let wallet: MetaAccountModel
    private let walletConnectService: WalletConnectService
    private let appRepository: AsyncAnyRepository<TonConnectApp>
    private let tonConnectService: TonConnectService
    private let eventCenter: EventCenterProtocol

    init(
        wallet: MetaAccountModel,
        walletConnectService: WalletConnectService,
        appRepository: AsyncAnyRepository<TonConnectApp>,
        tonConnectService: TonConnectService,
        eventCenter: EventCenterProtocol

    ) {
        self.wallet = wallet
        self.walletConnectService = walletConnectService
        self.appRepository = appRepository
        self.tonConnectService = tonConnectService
        self.eventCenter = eventCenter
    }
}

// MARK: - WalletConnectActiveSessionsInteractorInput

extension WalletConnectActiveSessionsInteractor: WalletConnectActiveSessionsInteractorInput {
    func setup(with output: WalletConnectActiveSessionsInteractorOutput) {
        self.output = output
        getSesstion()
        walletConnectService.set(listener: self)
    }

    func setupConnection(uri: String) async throws {
        switch wallet.ecosystem {
        case .regular:
            try await walletConnectService.connect(uri: uri)
        case .ton:
            try await tonConnectService.establishConnection(with: uri)
        }
    }
    
    func getSesstion() {
        switch wallet.ecosystem {
        case .regular:
            let sessions = walletConnectService.getSessions()
            output?.didReceive(sessions: sessions)
        case .ton:
            Task {
                let apps = try await appRepository.fetchAll()
                output?.didReceive(connectedApps: apps)
            }
        }
    }
}

// MARK: - WalletConnectServiceDelegate

extension WalletConnectActiveSessionsInteractor: WalletConnectServiceDelegate {
    func didChange(sessions: [Session]) {
        output?.didReceive(sessions: sessions)
    }
}

extension WalletConnectActiveSessionsInteractor: EventVisitorProtocol {
    func processTonConnectEstablished() {
        getSesstion()
    }
}
