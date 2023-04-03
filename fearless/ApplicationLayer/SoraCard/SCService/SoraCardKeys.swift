import Foundation

enum SoraCardKeys {
    static var apiKey: String =
        SoraCardKeys.variable(named: "SORA_CARD_API_KEY") ?? "6974528a-ee11-4509-b549-a8d02c1aec0d"
    static var domain: String =
        SoraCardKeys.variable(named: "SORA_CARD_DOMAIN") ?? "soracard.com"

    static var endpoint: String = SoraCardKeys.variable(named: "SORA_CARD_KYC_ENDPOINT_URL") ?? "https://kyc-test.soracard.com/mobile"
    static var username: String = SoraCardKeys.variable(named: "SORA_CARD_KYC_USERNAME") ?? "E7A6CB83-630E-4D24-88C5-18AAF96032A4"
    static var password: String = SoraCardKeys.variable(named: "SORA_CARD_KYC_PASSWORD") ?? "75A55B7E-A18F-4498-9092-58C7D6BDB333"

    static func variable(named name: String) -> String? {
        let processInfo = ProcessInfo.processInfo
        guard let value = processInfo.environment[name] else {
            return nil
        }
        return value
    }
}

enum PayWingsKeys {
    static var repositoryUrl: String = PayWingsKeys.variable(named: "PAY_WINGS_REPOSITORY_URL") ?? ""
    static var username: String = PayWingsKeys.variable(named: "PAY_WINGS_USERNAME") ?? ""
    static var password: String = PayWingsKeys.variable(named: "PAY_WINGS_PASSWORD") ?? ""

    static func variable(named name: String) -> String? {
        let processInfo = ProcessInfo.processInfo
        guard let value = processInfo.environment[name] else {
            return nil
        }
        return value
    }
}

enum XOneKeys {
    static var endpointRelease: String = XOneKeys.variable(named: "X1_ENDPOINT_URL_RELEASE") ?? ""
    static var widgetIdRelease: String = XOneKeys.variable(named: "X1_WIDGET_ID_RELEASE") ?? ""
    static var endpointDebug: String = XOneKeys.variable(named: "X1_ENDPOINT_URL_DEBUG") ?? ""
    static var widgetIdDebug: String = XOneKeys.variable(named: "X1_WIDGET_ID_DEBUG") ?? ""

    static func variable(named name: String) -> String? {
        let processInfo = ProcessInfo.processInfo
        guard let value = processInfo.environment[name] else {
            return nil
        }
        return value
    }
}
