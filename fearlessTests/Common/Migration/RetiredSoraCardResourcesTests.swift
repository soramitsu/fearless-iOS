import UIKit
import XCTest
@testable import fearless

/// SORA Card (with its PayWings sign-in, KYC flow and X1 top-up widget) was removed. None of its
/// copy or artwork may ship again, in any localization the app bundles.
final class RetiredSoraCardResourcesTests: XCTestCase {
    private static let retiredKeys: Set<String> = [
        "profile.soracard.title",
        "sora.card.status.failure.text",
        "sora.card.status.failure.title",
        "sora.card.status.pending.title",
        "sora.card.status.rejected.text",
        "sora.card.status.rejected.title",
        "sora.card.status.success.text",
        "sora.card.status.success.title",
        "terms.and.conditions.accept.and.continue",
        "terms.and.conditions.description",
        "terms.and.conditions.general.terms",
        "terms.and.conditions.privacy.policy",
        "terms.and.conditions.sora.community.alert.main",
        "terms.and.conditions.sora.community.alert.secondary",
        "terms.and.conditions.title",
        "verify.phone.number.title",
        "verification.rejected.screen.attempts.left",
        // PayWings OAuth SDK strings that only pt-PT carried.
        "cant.fetch.refresh",
        "common.back",
        "common.support",
        "common.try.again"
    ]

    // Namespaces that only the SORA Card SDK used.
    private static let retiredKeyPrefixes = [
        "sora.card.", "card.hub.", "card.issuance.", "cardhub.", "get.prepared.", "kyc.", "iban.", "payment.widget."
    ]

    // The card's name as the removed translations spelled it.
    private static let retiredServiceNames = [
        "sora card", "soracard", "cartão sora", "kartu sora", "sora kartı", "thẻ sora", "soraカード", "sora卡", "paywings"
    ]

    private static let retiredImageNames = [
        "iconSoraCard",
        "soraCardBoard",
        "soraCardFront",
        "soraCardStatusFailure",
        "soraCardStatusPending",
        "soraCardStatusSuccess"
    ]

    func testNoLocalizationCarriesSoraCardStrings() throws {
        let localizations = try bundledLocalizations()
        XCTAssertTrue(localizations.contains { $0.lastPathComponent == "en.lproj" })

        for localization in localizations {
            for table in ["Localizable.strings", "Localizable.stringsdict"] {
                let entries = try loadTable(table, in: localization)
                let tableName = "\(localization.lastPathComponent)/\(table)"

                for key in entries.keys {
                    XCTAssertFalse(Self.retiredKeys.contains(key), "\(tableName): \(key)")
                    XCTAssertFalse(Self.retiredKeyPrefixes.contains { key.hasPrefix($0) }, "\(tableName): \(key)")
                }

                for (key, value) in entries {
                    let text = flattenedText(value).lowercased()
                    for name in Self.retiredServiceNames {
                        XCTAssertFalse(text.contains(name), "\(tableName): \(key) mentions \(name)")
                    }
                }
            }
        }
    }

    func testMicrophonePurposeStringNoLongerMentionsKYC() throws {
        // The key stays: the binary references AVCaptureDevice.requestAccess(for:) for the QR scanner,
        // and App Store processing can require a microphone purpose string for that API.
        let purpose = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String)
        XCTAssertFalse(purpose.isEmpty)
        XCTAssertFalse(purpose.localizedCaseInsensitiveContains("KYC"))

        for localization in try bundledLocalizations() {
            let entries = try loadTable("InfoPlist.strings", in: localization)
            for (key, value) in entries {
                XCTAssertFalse(
                    flattenedText(value).localizedCaseInsensitiveContains("KYC"),
                    "\(localization.lastPathComponent)/InfoPlist.strings: \(key)"
                )
            }
        }
    }

    func testSoraCardArtworkIsNotBundled() {
        for name in Self.retiredImageNames {
            XCTAssertNil(UIImage(named: name, in: Bundle.main, compatibleWith: nil), name)
        }
    }

    private func bundledLocalizations() throws -> [URL] {
        let resources = try XCTUnwrap(Bundle.main.resourceURL)
        return try FileManager.default
            .contentsOfDirectory(at: resources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "lproj" }
    }

    private func loadTable(_ name: String, in localization: URL) throws -> [String: Any] {
        let url = localization.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }

        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: Any], url.path)
    }

    private func flattenedText(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let dictionary as [String: Any]:
            return dictionary.values.map(flattenedText).joined(separator: "\n")
        case let array as [Any]:
            return array.map(flattenedText).joined(separator: "\n")
        default:
            return ""
        }
    }
}
