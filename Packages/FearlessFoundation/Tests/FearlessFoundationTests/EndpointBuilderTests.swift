import XCTest
@testable import FearlessFoundation

final class EndpointBuilderTests: XCTestCase {
    func testBuildURL_whenParametersAreEncodable_thenReplacesStringAndIntegerParameters() throws {
        let builder = EndpointBuilder(urlTemplate: "https://example.com/{chain}/accounts/{accountId}")
        let url = try builder.buildURL(with: EndpointParameters(chain: "sora", accountId: 42))

        XCTAssertEqual(url.absoluteString, "https://example.com/sora/accounts/42")
    }

    func testBuildParameterURL_whenTemplateHasSingleParameter_thenReplacesIt() throws {
        let builder = EndpointBuilder(urlTemplate: "https://example.com/account/{address}")
        let url = try builder.buildParameterURL("cnVudGltZQ")

        XCTAssertEqual(url.absoluteString, "https://example.com/account/cnVudGltZQ")
    }

    func testBuildParameterURL_whenTemplateHasMultipleParameters_thenThrows() {
        let builder = EndpointBuilder(urlTemplate: "https://example.com/{chain}/{address}")

        XCTAssertThrowsError(try builder.buildParameterURL("sora")) { error in
            XCTAssertEqual(error as? EndpointBuilderError, .singleParameterExpected)
        }
    }

    func testBuildRegex_whenTemplateContainsSpecialCharacters_thenEscapesLiteralUrlParts() throws {
        let builder = EndpointBuilder(urlTemplate: "https://example.com/api/{path}?value={value}")

        XCTAssertEqual(
            try builder.buildRegex(),
            "https://example\\.com/api/[^/?&]+\\?value=[^/?&]+"
        )
    }
}

private struct EndpointParameters: Encodable {
    let chain: String
    let accountId: Int
}
