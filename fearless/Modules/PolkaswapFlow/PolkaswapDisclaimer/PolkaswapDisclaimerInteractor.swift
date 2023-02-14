import UIKit
import SoraKeystore

enum PolkaswapDisclaimerKeys: String {
    case polkaswapDisclaimerIsRead
}

protocol PolkaswapDisclaimerInteractorOutput: AnyObject {
    func didReceiveDisclaimer(isRead: Bool)
}

final class PolkaswapDisclaimerInteractor {
    // MARK: - Private properties

    private weak var output: PolkaswapDisclaimerInteractorOutput?
    private let userDefaultsStorage: SettingsManagerProtocol

    init(userDefaultsStorage: SettingsManagerProtocol) {
        self.userDefaultsStorage = userDefaultsStorage
    }

    // MARK: - Private func

    private func fetchDisclaimerRead() {
        let isRead = userDefaultsStorage.bool(for: PolkaswapDisclaimerKeys.polkaswapDisclaimerIsRead.rawValue)
        output?.didReceiveDisclaimer(isRead: isRead.or(false))
    }
}

// MARK: - PolkaswapDisclaimerInteractorInput

extension PolkaswapDisclaimerInteractor: PolkaswapDisclaimerInteractorInput {
    func setup(with output: PolkaswapDisclaimerInteractorOutput) {
        self.output = output
        fetchDisclaimerRead()
    }

    func setDisclaimerIsRead() {
        userDefaultsStorage.set(value: true, for: PolkaswapDisclaimerKeys.polkaswapDisclaimerIsRead.rawValue)
    }
}
