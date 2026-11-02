import XCTest
@testable import fearless

/// The send screen's address warnings, read in every language the app bundles.
final class ScamInfoDescriptionTests: XCTestCase {
    private let languages = Bundle.main.localizations.filter { $0 != "Base" }.sorted()
    /// Flags whose warning names the asset, and flags whose warning does not.
    private let assetNamingTypes: [ScamInfo.ScamType] = [.scam, .donation, .sanctions, .highRiskOrganization, .theft]
    private let typesWithoutAsset: [ScamInfo.ScamType] = [.exchange, .service, .lowScore]

    func testEveryFlagHasAWarning() {
        let covered = assetNamingTypes + typesWithoutAsset + [.unknown]
        XCTAssertEqual(covered.count, ScamInfo.ScamType.allCases.count)
        XCTAssertEqual(Set(covered), Set(ScamInfo.ScamType.allCases))
    }

    func testWarningsThatNameTheAssetShowItOnceInEveryLanguage() throws {
        XCTAssertGreaterThan(languages.count, 1)
        for language in languages {
            for type in assetNamingTypes {
                let text = try XCTUnwrap(
                    type.description(for: Locale(identifier: language), assetName: "DOT"),
                    "\(language) \(type)"
                )
                XCTAssertEqual(text.components(separatedBy: "DOT").count - 1, 1, "\(language) \(type): \(text)")
                XCTAssertNil(text.range(of: "[{}%]", options: .regularExpression), "\(language) \(type): \(text)")
            }
        }
    }

    func testWarningsWithoutAnAssetHaveNoPlaceholders() throws {
        for language in languages {
            for type in typesWithoutAsset {
                let text = try XCTUnwrap(
                    type.description(for: Locale(identifier: language), assetName: "DOT"),
                    "\(language) \(type)"
                )
                XCTAssertNil(text.range(of: "[{}%]", options: .regularExpression), "\(language) \(type): \(text)")
            }
        }
        XCTAssertNil(ScamInfo.ScamType.unknown.description(for: Locale(identifier: "en"), assetName: "DOT"))
    }

    /// The confirm screen's sheet used to give the sanctions sentence for every flag.
    func testConfirmationAlertRepeatsTheFlagsOwnWarningInEveryLanguage() {
        let english = ScamInfo.ScamType.allCases.map {
            $0.confirmationAlertMessage(for: Locale(identifier: "en"), assetName: "DOT")
        }
        for language in languages {
            let locale = Locale(identifier: language)
            var messages: [ScamInfo.ScamType: String] = [:]
            for type in ScamInfo.ScamType.allCases {
                let message = type.confirmationAlertMessage(for: locale, assetName: "DOT")
                messages[type] = message
                XCTAssertEqual(
                    message,
                    type.description(for: locale, assetName: "DOT")
                        ?? R.string.localizable.scamWarningAlertSubtitle("DOT", preferredLanguages: locale.rLanguages),
                    "\(language) \(type)"
                )
                let namesTheAsset = type == .unknown || assetNamingTypes.contains(type)
                XCTAssertEqual(
                    message.components(separatedBy: "DOT").count - 1,
                    namesTheAsset ? 1 : 0,
                    "\(language) \(type): \(message)"
                )
                XCTAssertNil(message.range(of: "[{}%]", options: .regularExpression), "\(language) \(type): \(message)")
                XCTAssertFalse(message.hasPrefix("scam."), "\(language) \(type) shows its key: \(message)")
                if language != "en" {
                    XCTAssertFalse(english.contains(message), "\(language) \(type) is in English: \(message)")
                }
            }
            XCTAssertEqual(Set(messages.values).count, ScamInfo.ScamType.allCases.count, "\(language): \(messages)")
        }
    }

    func testConfirmationAlertInEnglishAndTurkish() {
        let english = Locale(identifier: "en")
        XCTAssertEqual(
            ScamInfo.ScamType.exchange.confirmationAlertMessage(for: english, assetName: "DOT"),
            "This address is marked as an exchange, " +
                "be careful as the deposit and withdrawal addresses may be different."
        )
        XCTAssertEqual(
            ScamInfo.ScamType.service.confirmationAlertMessage(for: english, assetName: "DOT"),
            "This address is marked as a financial service, " +
                "be careful as the deposit and withdrawal addresses may be different."
        )
        XCTAssertEqual(
            ScamInfo.ScamType.donation.confirmationAlertMessage(for: english, assetName: "DOT"),
            "This address is marked as a charity's donation address. " +
                "Make sure you mean to donate before you send DOT."
        )
        XCTAssertEqual(
            ScamInfo.ScamType.theft.confirmationAlertMessage(for: english, assetName: "DOT"),
            "This address has been flagged due to evidence of theft. " +
                "We strongly recommend that you don't send DOT to this account."
        )
        XCTAssertEqual(
            ScamInfo.ScamType.lowScore.confirmationAlertMessage(for: english, assetName: "DOT"),
            "The address you are about to transfer to has low onchain activity, " +
                "which may indicate a potential scammer or sybil attacker."
        )
        XCTAssertEqual(
            ScamInfo.ScamType.unknown.confirmationAlertMessage(for: english, assetName: "DOT"),
            "We strongly recommend that you don't send DOT to this account."
        )
        XCTAssertEqual(
            ScamInfo.ScamType.unknown.confirmationAlertMessage(for: Locale(identifier: "tr"), assetName: "DOT"),
            "Bu hesaba DOT göndermemenizi şiddetle tavsiye ederiz."
        )
        XCTAssertEqual(R.string.localizable.commonWarning(preferredLanguages: ["tr"]), "Uyarı")
    }

    func testScamWarningNamesTheAssetInEnglishAndTurkish() {
        XCTAssertEqual(
            ScamInfo.ScamType.scam.description(for: Locale(identifier: "en"), assetName: "DOT"),
            "This address has been flagged due to evidence of a scam. " +
                "We strongly recommend that you don't send DOT to this account."
        )
        XCTAssertEqual(
            ScamInfo.ScamType.scam.description(for: Locale(identifier: "tr"), assetName: "DOT"),
            "Bu adres dolandırıcılık kanıtı nedeniyle işaretlendi. " +
                "Bu hesaba DOT göndermemenizi şiddetle tavsiye ederiz."
        )
        XCTAssertEqual(
            ScamInfo.ScamType.exchange.description(for: Locale(identifier: "en"), assetName: "DOT"),
            "This address is marked as an exchange, " +
                "be careful as the deposit and withdrawal addresses may be different."
        )
    }
}
