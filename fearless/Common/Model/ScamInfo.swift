import Foundation
import RobinHood

struct ScamInfo: Identifiable, Codable, Equatable, Hashable {
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

    enum ScamType: String, Codable, CaseIterable {
        case unknown
        case scam
        case donation
        case exchange
        case sanctions
        case lowScore = "Low network activity"

        init?(from string: String) {
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let type = Self.allCases.first(where: { $0.rawValue.lowercased() == normalized }) else {
                return nil
            }
            self = type
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
            case .lowScore:
                return R.string.localizable.scamDescriptionLowscoreText(preferredLanguages: locale.rLanguages)
            }
        }

        /// The sheet behind the confirm screen's recipient warning repeats the Send screen's warning
        /// for this flag; a flag the app does not recognise gets the general advice.
        func confirmationAlertMessage(for locale: Locale, assetName: String) -> String {
            description(for: locale, assetName: assetName)
                ?? R.string.localizable.scamWarningAlertSubtitle(assetName, preferredLanguages: locale.rLanguages)
        }
    }
}
