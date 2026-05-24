import Foundation

public protocol SettingsManagerProtocol: AnyObject {
    func set(value: Bool, for key: String)
    func set(value: Int, for key: String)
    func set(value: Double, for key: String)
    func set(value: String, for key: String)
    func set(value: Data, for key: String)
    func set(anyValue: Any, for key: String)
    func bool(for key: String) -> Bool?
    func integer(for key: String) -> Int?
    func double(for key: String) -> Double?
    func string(for key: String) -> String?
    func data(for key: String) -> Data?
    func anyValue(for key: String) -> Any?
    func removeValue(for key: String)
    func removeAll()
}

public extension SettingsManagerProtocol {
    @discardableResult
    func set<T: Encodable>(value: T, for key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else {
            return false
        }

        set(value: data, for: key)
        return true
    }

    func value<T: Decodable>(of type: T.Type, for key: String) -> T? {
        guard let data = data(for: key) else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }
}

public final class SettingsManager: SettingsManagerProtocol {
    public static let shared = SettingsManager()

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func set(value: Bool, for key: String) {
        defaults.set(value, forKey: key)
    }

    public func set(value: Int, for key: String) {
        defaults.set(value, forKey: key)
    }

    public func set(value: Double, for key: String) {
        defaults.set(value, forKey: key)
    }

    public func set(value: String, for key: String) {
        defaults.set(value, forKey: key)
    }

    public func set(value: Data, for key: String) {
        defaults.set(value, forKey: key)
    }

    public func set(anyValue: Any, for key: String) {
        defaults.set(anyValue, forKey: key)
    }

    public func bool(for key: String) -> Bool? {
        defaults.object(forKey: key).map { _ in defaults.bool(forKey: key) }
    }

    public func integer(for key: String) -> Int? {
        defaults.object(forKey: key).map { _ in defaults.integer(forKey: key) }
    }

    public func double(for key: String) -> Double? {
        defaults.object(forKey: key).map { _ in defaults.double(forKey: key) }
    }

    public func string(for key: String) -> String? {
        defaults.string(forKey: key)
    }

    public func data(for key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func anyValue(for key: String) -> Any? {
        defaults.object(forKey: key)
    }

    public func removeValue(for key: String) {
        defaults.removeObject(forKey: key)
    }

    public func removeAll() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        defaults.removePersistentDomain(forName: bundleIdentifier)
    }
}

public final class InMemorySettingsManager: SettingsManagerProtocol {
    private var settings: [String: Any] = [:]

    public init() {}

    public func set(value: Bool, for key: String) {
        settings[key] = value
    }

    public func set(value: Int, for key: String) {
        settings[key] = value
    }

    public func set(value: Double, for key: String) {
        settings[key] = value
    }

    public func set(value: String, for key: String) {
        settings[key] = value
    }

    public func set(value: Data, for key: String) {
        settings[key] = value
    }

    public func set(anyValue: Any, for key: String) {
        settings[key] = anyValue
    }

    public func bool(for key: String) -> Bool? {
        settings[key] as? Bool
    }

    public func integer(for key: String) -> Int? {
        settings[key] as? Int
    }

    public func double(for key: String) -> Double? {
        settings[key] as? Double
    }

    public func string(for key: String) -> String? {
        settings[key] as? String
    }

    public func data(for key: String) -> Data? {
        settings[key] as? Data
    }

    public func anyValue(for key: String) -> Any? {
        settings[key]
    }

    public func removeValue(for key: String) {
        settings[key] = nil
    }

    public func removeAll() {
        settings.removeAll()
    }
}
