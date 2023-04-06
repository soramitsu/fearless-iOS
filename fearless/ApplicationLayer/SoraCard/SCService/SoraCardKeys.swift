import Foundation

enum SoraCardKeys {
    static var apiKey: String =
        SoraCardKeys.variable(named: "SORA_CARD_API_KEY") ?? ""
    static var domain: String =
        SoraCardKeys.variable(named: "SORA_CARD_DOMAIN") ?? ""

    static var endpoint: String = SoraCardKeys.variable(named: "SORA_CARD_KYC_ENDPOINT_URL") ?? ""
    static var username: String = SoraCardKeys.variable(named: "SORA_CARD_KYC_USERNAME") ?? ""
    static var password: String = SoraCardKeys.variable(named: "SORA_CARD_KYC_PASSWORD") ?? ""

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
