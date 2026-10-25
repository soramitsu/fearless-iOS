import Foundation

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

        let toggles: [LocalListToggle] = dict.compactMap { _, value in
            guard let data = value as? Data else {
                return nil
            }
            return try? decoder.decode(LocalListToggle.self, from: data)
        }

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

    static let toggles: [LocalListToggle] = [
        LocalListToggle.chains,
        LocalListToggle.tonEnv
    ]

    var chainsListToggle: LocalListToggle? {
        get {
            getToggle(for: "0")
        }
        set {
            if let newValue {
                set(toggle: newValue)
            }
        }
    }

    var tonEnvListToggle: LocalListToggle {
        get {
            Self.tonEnvironment(
                stored: getToggle(for: "1"),
                honorsStoredValue: Self.honorsStoredTonEnvironment
            )
        }
        set {
            set(toggle: newValue)
        }
    }

    // Releases 4.0.2 to 4.1.0 had a hidden debug menu that could switch TON to
    // testnet and store that choice here. Release builds have no way to switch back,
    // so they always use TON mainnet; the stored value is left untouched.
    #if F_DEV
        static let honorsStoredTonEnvironment = true
    #else
        static let honorsStoredTonEnvironment = false
    #endif

    static func tonEnvironment(stored: LocalListToggle?, honorsStoredValue: Bool) -> LocalListToggle {
        guard honorsStoredValue, let stored else {
            return LocalListToggle.tonEnv
        }

        return stored
    }
}
