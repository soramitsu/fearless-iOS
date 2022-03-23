import Foundation

struct AboutData {
    let websiteUrl: URL
    let opensourceUrl: URL
    let twitter: URL
    let youTube: URL
    let instagram: URL
    let medium: URL
    let wiki: URL
    let telegram: TelegramData
    let writeUs: SupportData
    let version: String
    let legal: LegalData
}

struct TelegramData {
    let fearlessWallet: URL
    let fearlessAnnouncements: URL
    let fearlessHappiness: URL
}
