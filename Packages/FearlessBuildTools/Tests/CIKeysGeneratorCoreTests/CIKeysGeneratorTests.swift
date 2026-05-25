import CIKeysGeneratorCore
import XCTest

final class CIKeysGeneratorTests: XCTestCase {
    func testRender_whenEnvironmentContainsValues_thenReplacesPlaceholders() throws {
        let template = """
        enum WalletConnect {
            static var projectId: String = "{{ argument.walletConnectProjectId }}"
        }
        """

        let output = try CIKeysGenerator.render(
            template: template,
            environment: ["FL_WALLET_CONNECT_PROJECT_ID": "wallet-connect-id"]
        )

        XCTAssertTrue(output.contains("wallet-connect-id"))
    }

    func testRender_whenEnvironmentValueMissing_thenUsesEmptyString() throws {
        let template = #"static var apiKey: String = "{{ argument.alchemyApiKey }}""#

        let output = try CIKeysGenerator.render(template: template, environment: [:])

        XCTAssertEqual(output, #"static var apiKey: String = """#)
    }

    func testRender_whenDebugValueMissing_thenUsesReleaseFallback() throws {
        let template = #"static var projectId: String = "{{ argument.walletConnectProjectIdDebug }}""#

        let output = try CIKeysGenerator.render(
            template: template,
            environment: ["FL_WALLET_CONNECT_PROJECT_ID": "release-wallet-connect-id"]
        )

        XCTAssertEqual(output, #"static var projectId: String = "release-wallet-connect-id""#)
    }

    func testRender_whenValueContainsSwiftStringEscapes_thenEscapesGeneratedLiteral() throws {
        let template = #"static var apiKey: String = "{{ argument.okxSecretKey }}""#

        let output = try CIKeysGenerator.render(
            template: template,
            environment: ["FL_OKX_SECRET_KEY": #"line 1\line "2""# + "\nend"]
        )

        XCTAssertEqual(output, #"static var apiKey: String = "line 1\\line \"2\"\nend""#)
    }

    func testRender_whenTemplateHasUnknownArgument_thenThrows() {
        XCTAssertThrowsError(
            try CIKeysGenerator.render(
                template: #"static var value: String = "{{ argument.unknown }}""#,
                environment: [:]
            )
        ) { error in
            XCTAssertEqual(error as? CIKeysGeneratorError, .unknownArgument("unknown"))
        }
    }
}
