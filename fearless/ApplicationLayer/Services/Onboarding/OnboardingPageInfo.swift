import Foundation

struct OnboardingPageInfo: Decodable {
    let title: PageTitle?
    let description: String?
    let image: URL?
}

struct PageTitle: Decodable {
    let text: String
    let color: String
}
