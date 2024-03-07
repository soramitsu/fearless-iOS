struct OnboardingConfigWrapper: Decodable {
    let en: OnboardingConfig

    enum CodingKeys: String, CodingKey {
        case en = "en-EN"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        en = try values.decode(OnboardingConfig.self, forKey: .en)
    }
}

struct OnboardingConfig: Decodable {
    let new: [OnboardingPageInfo]
    let regular: [OnboardingPageInfo]
}
