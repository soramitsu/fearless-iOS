import Foundation
import SoraKeystore

protocol ReceiveAccountViewModelProtocol {
    var displayName: String { get }
    var address: String { get }
}

struct ReceiveAccountViewModel: ReceiveAccountViewModelProtocol {
    let settings: SettingsManagerProtocol

    init(settings: SettingsManagerProtocol) {
        self.settings = settings
    }

    var displayName: String { settings.selectedAccount?.username ?? "" }

    var address: String { settings.selectedAccount?.address ?? "" }
}
