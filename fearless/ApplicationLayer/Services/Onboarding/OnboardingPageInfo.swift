import Foundation

struct OnboardingPageInfo: Decodable {
    let title: OnboardingPageTitle?
    let description: String?
    let image: URL?
}

struct OnboardingPageTitle: Decodable {
    let text: String
    let color: String
}
