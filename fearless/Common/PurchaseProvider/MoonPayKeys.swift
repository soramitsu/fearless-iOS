import Foundation

enum MoonPayKeys {
    static var publicKey: String =
        MoonPayKeys.variable(named: "MOONPAY_PUBLIC_KEY") ?? MoonPayCIKeys.publicKey

    static func variable(named name: String) -> String? {
        let processInfo = ProcessInfo.processInfo
        guard let value = processInfo.environment[name] else {
            return nil
        }
        return value
    }
}
