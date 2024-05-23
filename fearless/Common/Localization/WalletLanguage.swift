import Foundation

private let kDefaultsKeyName = "l10n_lang"

public enum WalletLanguage: String, CaseIterable {
    case english = "en"
    case japan = "ja"
    case russian = "ru"
    case spanishCo = "es-CO"
    case khmer = "km"
    case bashkir = "ba-RU"
    case italian = "it"
    case french = "fr"
    case ukrainian = "uk"
    case chineseSimplified = "zh-Hans"
    case chineseTaiwan = "zh-Hant-TW"
    case croatian = "hr"
    case estonian = "et"
    case filipino = "fil"
    case finnish = "fi"
    case indonesian = "id"
    case korean = "ko"
    case malay = "ms"
    case spanishEs = "es"
    case swedish = "sv"
    case thai = "th"
}

public extension WalletLanguage {
    static var defaultLanguage: WalletLanguage {
        .english
    }
}

private final class BundleLoadHelper {}
