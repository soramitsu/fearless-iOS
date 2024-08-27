import Foundation
import SoraKeystore
import SSFSingleValueCache
import RobinHood

final class LocalToggleService: ApplicationServiceProtocol {
    
    static let shared = LocalToggleService()

    private lazy var storage = UserDefaults(suiteName: "Feature.Toggle.List")
    private lazy var decoder = JSONDecoder()
    private lazy var encoder = JSONEncoder()
    
    private init() {}
    
    lazy var list: [LocalListToggle] = {
        guard let dict = storage?.dictionaryRepresentation() else {
            return []
        }
        let toggles: [LocalListToggle] = dict.compactMap({ (key, value) in
            guard let data = value as? Data else {
                return nil
            }
            return try? decoder.decode(LocalListToggle.self, from: data)
        })
        return toggles
    }()
    
    func setup() {
        let dict = storage?.dictionaryRepresentation()
        Self.toggles.forEach { toggle in
            guard 
                dict?[toggle.key] == nil,
                let data = try? encoder.encode(toggle)
            else {
                return
            }
            storage?.set(data, forKey: toggle.key)
        }
        storage?.synchronize()
    }
    
    func throttle() {}
    
    private func getToggle(for key: String) -> LocalListToggle? {
        guard 
            let data = storage?.value(forKey: key) as? Data,
            let toggle = try? decoder.decode(LocalListToggle.self, from: data)
        else {
            return nil
        }
        return toggle
    }
    
    func set(toggle: LocalListToggle) {
        guard let data = try? encoder.encode(toggle) else {
            return
        }
        storage?.setValue(data, forKey: toggle.key)
        storage?.synchronize()
    }
    
    // MARK: - Registry
    
    /// Default toggles
    /// New Toggle should be register in Feature.Toggle.List user defaults 
    /// For shown in debug menu list
    static let toggles: [LocalListToggle] = [
        LocalListToggle.chains,
        LocalListToggle.tonEnv
    ]
    
    var chainsListToggle: LocalListToggle {
        get {
            getToggle(for: "0") ?? LocalListToggle.chains
        }
        set {
            set(toggle: newValue)
        }
    }
    
    var tonEnvListToggle: LocalListToggle {
        get {
            getToggle(for: "1") ?? LocalListToggle.tonEnv
        }
        set {
            set(toggle: newValue)
        }
    }
}
