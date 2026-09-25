import UIKit
import SoraKeystore

enum PolkaswapDisclaimerKeys: String {
    case polkaswapDisclaimerIsRead2
    case polkaswapDisclaimerAcceptedVersion
}

/// The transaction boundary must use the same persisted acceptance as the
/// disclaimer screen. Keeping an integer version lets a future wording change
/// invalidate an older acceptance without relying on controller state.
enum PolkaswapDisclaimerPolicy {
    static let currentVersion = 2

    static func isAccepted(in storage: SettingsManagerProtocol = SettingsManager.shared) -> Bool {
        if storage.integer(for: PolkaswapDisclaimerKeys.polkaswapDisclaimerAcceptedVersion.rawValue) == currentVersion {
            return true
        }

        // `polkaswapDisclaimerIsRead2` is the released persistence for version
        // 2. Migrate it once; it must not automatically accept a future version.
        guard currentVersion == 2,
              storage.bool(for: PolkaswapDisclaimerKeys.polkaswapDisclaimerIsRead2.rawValue) == true else {
            return false
        }

        storage.set(
            value: currentVersion,
            for: PolkaswapDisclaimerKeys.polkaswapDisclaimerAcceptedVersion.rawValue
        )
        return true
    }

    static func acceptCurrentVersion(
        in storage: SettingsManagerProtocol = SettingsManager.shared
    ) {
        storage.set(
            value: currentVersion,
            for: PolkaswapDisclaimerKeys.polkaswapDisclaimerAcceptedVersion.rawValue
        )
        storage.set(value: true, for: PolkaswapDisclaimerKeys.polkaswapDisclaimerIsRead2.rawValue)
    }
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

    private func fetchDisclaimerIsRead() {
        output?.didReceiveDisclaimer(
            isRead: PolkaswapDisclaimerPolicy.isAccepted(in: userDefaultsStorage)
        )
    }
}

// MARK: - PolkaswapDisclaimerInteractorInput

extension PolkaswapDisclaimerInteractor: PolkaswapDisclaimerInteractorInput {
    func setup(with output: PolkaswapDisclaimerInteractorOutput) {
        self.output = output
        fetchDisclaimerIsRead()
    }

    func setDisclaimerIsRead() {
        PolkaswapDisclaimerPolicy.acceptCurrentVersion(in: userDefaultsStorage)
    }
}
