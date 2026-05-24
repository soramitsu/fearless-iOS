import XCTest
@testable import FearlessFoundation

final class LocalizationResourceTests: XCTestCase {
    func testValue_whenRequestedForLocale_thenEvaluatesClosureWithLocale() {
        let resource = LocalizableResource { locale in
            "locale:\(locale.identifier)"
        }

        XCTAssertEqual(resource.value(for: Locale(identifier: "fr_FR")), "locale:fr_FR")
    }

    func testDateFormatterLocalizableResource_whenRequestedForLocale_thenAppliesLocaleToFormatter() {
        let formatter = DateFormatter()
        let resource = formatter.localizableResource()

        let localizedFormatter = resource.value(for: Locale(identifier: "ja_JP"))

        XCTAssertTrue(localizedFormatter === formatter)
        XCTAssertEqual(localizedFormatter.locale.identifier, "ja_JP")
    }

    func testNumberFormatterLocalizableResource_whenRequestedForLocale_thenAppliesLocaleToFormatter() {
        let formatter = NumberFormatter()
        let resource = formatter.localizableResource()

        let localizedFormatter = resource.value(for: Locale(identifier: "de_DE"))

        XCTAssertTrue(localizedFormatter === formatter)
        XCTAssertEqual(localizedFormatter.locale.identifier, "de_DE")
    }
}
