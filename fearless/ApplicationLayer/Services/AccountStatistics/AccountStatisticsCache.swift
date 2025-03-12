import SoraKeystore
import Foundation

protocol AccountStatisticsCache {
    func setLastUpdate(for address: String)
    func lastUpdate(for address: String) -> Date?
}

final class UserDefaultsAccountStatisticsCache {
    private let keyPrefix = "accountStatisticsCache."
    private let settings: SettingsManagerProtocol
    
    init(settings: SettingsManagerProtocol) {
        self.settings = settings
    }
    
    private func key(for address: String) -> String {
        keyPrefix + address
    }
}

extension UserDefaultsAccountStatisticsCache: AccountStatisticsCache {
    func setLastUpdate(for address: String) {
        settings.set(anyValue: Date(), for: key(for: address))
    }
    
    func lastUpdate(for address: String) -> Date? {
        settings.anyValue(for: key(for: address)) as? Date
    }
}
