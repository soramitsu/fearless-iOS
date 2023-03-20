import UIKit
import PayWingsOAuthSDK
import SoraKeystore

struct SoraCardSettingsKey {
    static func settingsKey(for wallet: MetaAccountModel) -> String {
        "sora-card-hidden-status-\(wallet.metaId)"
    }
}

final class SoraCardInfoBoardInteractor {
    // MARK: - Private properties

    private weak var output: SoraCardInfoBoardInteractorOutput?
    private let settings: SettingsManagerProtocol
    private let wallet: MetaAccountModel
    private let service: SCKYCService

    init(
        service: SCKYCService,
        settings: SettingsManagerProtocol,
        wallet: MetaAccountModel
    ) {
        self.service = service
        self.settings = settings
        self.wallet = wallet
    }
}

// MARK: - SoraCardInfoBoardInteractorInput

extension SoraCardInfoBoardInteractor: SoraCardInfoBoardInteractorInput {
    func setup(with output: SoraCardInfoBoardInteractorOutput) {
        self.output = output

        let key = SoraCardSettingsKey.settingsKey(for: wallet)
        settings.set(value: false, for: key)
    }

    func hideCard() {
        let key = SoraCardSettingsKey.settingsKey(for: wallet)
        settings.set(value: true, for: key)

        let hidden = settings.bool(for: key) ?? false
        output?.didReceive(hiddenState: hidden)
    }

    func fetchStatus() async -> SCKYCUserStatus? {
        await service.userStatus()
    }
}
