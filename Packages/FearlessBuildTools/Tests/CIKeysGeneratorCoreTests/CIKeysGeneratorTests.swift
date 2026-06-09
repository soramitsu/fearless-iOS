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

    func testRender_whenDebugValueIsWhitespace_thenUsesReleaseFallback() throws {
        let template = #"static var projectId: String = "{{ argument.walletConnectProjectIdDebug }}""#

        let output = try CIKeysGenerator.render(
            template: template,
            environment: [
                "FL_WALLET_CONNECT_PROJECT_ID": "release-wallet-connect-id",
                "FL_WALLET_CONNECT_PROJECT_ID_DEBUG": "   "
            ]
        )

        XCTAssertEqual(output, #"static var projectId: String = "release-wallet-connect-id""#)
    }

    func testRender_whenGoogleDebugValuesMissing_thenUsesReleaseFallbacks() throws {
        let template = """
        static var googleToken: String = "{{ argument.webClientIdDebug }}"
        static var googleUrlScheme: String = "{{ argument.fearlessGoogleUrlSchemeDebug }}"
        """

        let output = try CIKeysGenerator.render(
            template: template,
            environment: [
                "WEB_CLIENT_ID_RELEASE": "release-client-id",
                "FEARLESS_GOOGLE_URL_SCHEME_RELEASE": "release-url-scheme"
            ]
        )

        XCTAssertTrue(output.contains(#"static var googleToken: String = "release-client-id""#))
        XCTAssertTrue(output.contains(#"static var googleUrlScheme: String = "release-url-scheme""#))
    }

    func testRender_whenTonDebugKeyMissing_thenUsesReleaseFallback() throws {
        let template = #"static var tonApiKey: String = "{{ argument.tonApiKeyDebug }}""#

        let output = try CIKeysGenerator.render(
            template: template,
            environment: ["FL_TON_API_KEY": "release-ton-key"]
        )

        XCTAssertEqual(output, #"static var tonApiKey: String = "release-ton-key""#)
    }

    func testRender_whenCoinbaseSessionTokenProvided_thenReplacesPlaceholder() throws {
        let template = #"static var sessionToken: String = "{{ argument.coinbaseSessionToken }}""#

        let output = try CIKeysGenerator.render(
            template: template,
            environment: ["COINBASE_SESSION_TOKEN": "coinbase-session-token"]
        )

        XCTAssertEqual(output, #"static var sessionToken: String = "coinbase-session-token""#)
    }

    func testRender_whenRampHostApiKeyProvided_thenReplacesPlaceholder() throws {
        let template = #"static var hostApiKey: String = "{{ argument.rampHostApiKey }}""#

        let output = try CIKeysGenerator.render(
            template: template,
            environment: ["RAMP_HOST_API_KEY": "ramp-host-key"]
        )

        XCTAssertEqual(output, #"static var hostApiKey: String = "ramp-host-key""#)
    }

    func testRender_whenMoonbeamCrowdloanApiKeysProvided_thenReplacesPlaceholders() throws {
        let template = """
        static var devApiKey: String = "{{ argument.moonbeamCrowdloanDevApiKey }}"
        static var prodApiKey: String = "{{ argument.moonbeamCrowdloanProdApiKey }}"
        """

        let output = try CIKeysGenerator.render(
            template: template,
            environment: [
                "MOONBEAM_CROWDLOAN_DEV_API_KEY": "moonbeam-dev-key",
                "MOONBEAM_CROWDLOAN_PROD_API_KEY": "moonbeam-prod-key"
            ]
        )

        XCTAssertTrue(output.contains(#"static var devApiKey: String = "moonbeam-dev-key""#))
        XCTAssertTrue(output.contains(#"static var prodApiKey: String = "moonbeam-prod-key""#))
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
