/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

@objc(SSFSoraKeystoreInMemorySettingsManager)
public final class InMemorySettingsManager: NSObject, SettingsManagerProtocol {
    private var settings: [String: Any] = [:]

    public override init() {}

    public func set(value: Bool, for key: String) {
        settings[key] = value
    }

    public func bool(for key: String) -> Bool? {
        settings[key] as? Bool
    }

    public func set(value: Int, for key: String) {
        settings[key] = value
    }

    public func integer(for key: String) -> Int? {
        settings[key] as? Int
    }

    public func set(value: Double, for key: String) {
        settings[key] = value
    }

    public func double(for key: String) -> Double? {
        settings[key] as? Double
    }

    public func set(value: String, for key: String) {
        settings[key] = value
    }

    public func string(for key: String) -> String? {
        settings[key] as? String
    }

    public func set(value: Data, for key: String) {
        settings[key] = value
    }

    public func data(for key: String) -> Data? {
        settings[key] as? Data
    }

    public func anyValue(for key: String) -> Any? {
        settings[key]
    }

    public func set(anyValue: Any, for key: String) {
        settings[key] = anyValue
    }

    public func removeValue(for key: String) {
        settings[key] = nil
    }

    public func removeAll() {
        settings.removeAll()
    }
}
