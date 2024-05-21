import Foundation

struct OnboardingConfigPlatform: Decodable {
    let ios: [OnboardingConfigWrapper]
    let android: [OnboardingConfigWrapper]

    enum CodingKeys: String, CodingKey {
        case ios = "iOS"
        case android = "Android"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        ios = try values.decode([OnboardingConfigWrapper].self, forKey: .ios)
        android = try values.decode([OnboardingConfigWrapper].self, forKey: .android)
    }
}

struct OnboardingConfigWrapper: Decodable {
    let en: OnboardingConfig
    let minVersion: String
    let background: URL

    enum CodingKeys: String, CodingKey {
        case en = "en-EN"
        case minVersion
        case background
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        en = try values.decode(OnboardingConfig.self, forKey: .en)
        minVersion = try values.decode(String.self, forKey: .minVersion)
        background = try values.decode(URL.self, forKey: .background)
    }
}

struct OnboardingConfig: Decodable {
    let new: [OnboardingPageInfo]
    let regular: [OnboardingPageInfo]
}
