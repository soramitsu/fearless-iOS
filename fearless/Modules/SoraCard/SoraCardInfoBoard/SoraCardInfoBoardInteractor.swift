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
    private let service: SCKYCService
    private let data: SCKYCUserDataModel
    private let settings: SettingsManagerProtocol
    private let wallet: MetaAccountModel

    init(
        data: SCKYCUserDataModel,
        service: SCKYCService,
        settings: SettingsManagerProtocol,
        wallet: MetaAccountModel
    ) {
        self.data = data
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

    func getKYCStatus() {
        Task {
            do {
                try await service.refreshAccessToken()
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.output?.didReceive(error: error)
                }
                return
            }

            let response = await service.kycStatus()
            switch response {
            case let .failure(error):
                DispatchQueue.main.async { [weak self] in
                    self?.output?.didReceive(error: error)
                }
            case let .success(statuses):
                DispatchQueue.main.async { [weak self] in
                    self?.output?.didReceive(status: statuses.last)
                }
            }
        }
    }

    func hideCard() {
        let key = SoraCardSettingsKey.settingsKey(for: wallet)
        settings.set(value: true, for: key)

        let hidden = settings.bool(for: key) ?? false
        output?.didReceive(hiddenState: hidden)
    }
}
