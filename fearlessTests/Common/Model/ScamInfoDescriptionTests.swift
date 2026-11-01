import XCTest
@testable import fearless

/// The send screen's address warnings, read in every language the app bundles.
final class ScamInfoDescriptionTests: XCTestCase {
    private let languages = Bundle.main.localizations.filter { $0 != "Base" }.sorted()

    func testWarningsThatNameTheAssetShowItOnceInEveryLanguage() throws {
        XCTAssertGreaterThan(languages.count, 1)
        for language in languages {
            for type in [ScamInfo.ScamType.scam, .donation, .sanctions] {
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
            for type in [ScamInfo.ScamType.exchange, .lowScore] {
                let text = try XCTUnwrap(
                    type.description(for: Locale(identifier: language), assetName: "DOT"),
                    "\(language) \(type)"
                )
                XCTAssertNil(text.range(of: "[{}%]", options: .regularExpression), "\(language) \(type): \(text)")
            }
        }
        XCTAssertNil(ScamInfo.ScamType.unknown.description(for: Locale(identifier: "en"), assetName: "DOT"))
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
    }
}
