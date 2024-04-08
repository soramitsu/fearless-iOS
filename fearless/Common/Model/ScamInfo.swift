import Foundation
import RobinHood

struct ScamInfo: Identifiable, Codable, Equatable {
    var identifier: String {
        address
    }

    let name: String
    let address: String
    let type: ScamType
    let subtype: String

    enum CodingKeys: String, CodingKey {
        case name
        case address
        case type
        case subtype
    }

    enum ScamType: String, Codable {
        case unknown
        case scam
        case donation
        case exchange
        case sanctions
        case nftSpam

        init?(from string: String) {
            self.init(rawValue: string.lowercased())
        }

        var isScam: Bool {
            switch self {
            case .scam:
                return true
            default:
                return false
            }
        }

        func description(for locale: Locale, assetName: String) -> String? {
            switch self {
            case .unknown:
                return nil
            case .scam:
                return R.string.localizable
                    .scamDescriptionScamStub(assetName, preferredLanguages: locale.rLanguages)
            case .donation:
                return R.string.localizable
                    .scamDescriptionDonationStub(assetName, preferredLanguages: locale.rLanguages)
            case .exchange:
                return R.string.localizable
                    .scamDescriptionExchangeStub(preferredLanguages: locale.rLanguages)
            case .sanctions:
                return R.string.localizable
                    .scamDescriptionSanctionsStub(assetName, preferredLanguages: locale.rLanguages)
            case .nftSpam:
                return R.string.localizable.nftSpamWarning(preferredLanguages: locale.rLanguages)
            }
        }
    }
}
