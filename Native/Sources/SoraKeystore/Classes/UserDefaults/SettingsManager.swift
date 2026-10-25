/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

@objc(SSFSoraKeystoreSettingsManager)
public class SettingsManager: NSObject, SettingsManagerProtocol {
    public static let shared: SettingsManager = .init()

    private override init() {}

    public func set(value: Bool, for key: String) {
        UserDefaults.standard.set(value, forKey: key)
        UserDefaults.standard.synchronize()
    }

    public func set(value: Int, for key: String) {
        UserDefaults.standard.set(value, forKey: key)
        UserDefaults.standard.synchronize()
    }

    public func set(value: Double, for key: String) {
        UserDefaults.standard.set(value, forKey: key)
        UserDefaults.standard.synchronize()
    }

    public func set(value: String, for key: String) {
        UserDefaults.standard.setValue(value, forKey: key)
        UserDefaults.standard.synchronize()
    }

    public func set(value: Data, for key: String) {
        UserDefaults.standard.setValue(value, forKey: key)
        UserDefaults.standard.synchronize()
    }

    public func set(anyValue: Any, for key: String) {
        UserDefaults.standard.setValue(anyValue, forKey: key)
        UserDefaults.standard.synchronize()
    }

    public func bool(for key: String) -> Bool? {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return nil
        }

        return UserDefaults.standard.bool(forKey: key)
    }

    public func integer(for key: String) -> Int? {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return nil
        }

        return UserDefaults.standard.integer(forKey: key)
    }

    public func double(for key: String) -> Double? {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return nil
        }

        return UserDefaults.standard.double(forKey: key)
    }

    public func string(for key: String) -> String? {
        UserDefaults.standard.value(forKey: key) as? String
    }

    public func data(for key: String) -> Data? {
        UserDefaults.standard.value(forKey: key) as? Data
    }

    public func anyValue(for key: String) -> Any? {
        UserDefaults.standard.value(forKey: key)
    }

    public func removeValue(for key: String) {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.synchronize()
    }

    public func removeAll() {
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
    }
}
