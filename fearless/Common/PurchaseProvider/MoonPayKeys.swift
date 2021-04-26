import Foundation

enum MoonPayKeys {
    static var secretKey: String =
        MoonPayKeys.variable(named: "MOONPAY_PRODUCTION_SECRET") ?? MoonPayCIKeys.secretKey
    static var testSecretKey: String =
        MoonPayKeys.variable(named: "MOONPAY_TEST_SECRET") ?? MoonPayCIKeys.testSecretKey

    static func variable(named name: String) -> String? {
        let processInfo = ProcessInfo.processInfo
        guard let value = processInfo.environment[name] else {
            return nil
        }
        return value
    }
}
