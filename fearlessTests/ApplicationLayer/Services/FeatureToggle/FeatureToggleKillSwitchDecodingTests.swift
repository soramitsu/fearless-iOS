import XCTest
@testable import fearless

/// The live `appConfigs/feature_toggle` payload and the prepared emergency veto template
/// (root `config/remote-config/feature-toggle.veto-only.prepared.json`) must decode to the
/// same capability state on every parser: absent keys never pause anything, explicit
/// `false` pauses, and only explicit values may record or lift a remembered veto.
final class FeatureToggleKillSwitchDecodingTests: XCTestCase {
    private static let livePayload = #"{"pendulum_case_enabled":false,"nft_enabled":false,"dapp_enabled":false}"#
    private static let emergencyVetoTemplate = """
    {"pendulum_case_enabled":false,"nft_enabled":false,"dapp_enabled":false,\
    "bitcoin_send_enabled":false,"solana_send_enabled":false,\
    "polkaswap_mutations_enabled":false,"demeter_mutations_enabled":false}
    """

    func testLivePayload_whenDecoded_thenBitcoinSolanaAndPolkaswapStayEnabled() throws {
        for decoder in Self.decoders {
            let config = try decode(Self.livePayload, with: decoder)

            XCTAssertTrue(config.bitcoinSendEnabled)
            XCTAssertTrue(config.solanaSendEnabled)
            XCTAssertTrue(config.polkaswapMutationsEnabled)
            XCTAssertTrue(config.explicitKillSwitches.isEmpty)
        }
        let production = try decode(Self.livePayload, with: GithubJSONDecoder())
        XCTAssertEqual(production.pendulumCaseEnabled, false)
        XCTAssertEqual(production.nftEnabled, false)
    }

    func testBitcoinVeto_whenDecoded_thenOnlyBitcoinSendIsVetoed() throws {
        for decoder in Self.decoders {
            let config = try decode(#"{"bitcoin_send_enabled":false}"#, with: decoder)

            XCTAssertFalse(config.bitcoinSendEnabled)
            XCTAssertTrue(config.solanaSendEnabled)
            XCTAssertTrue(config.polkaswapMutationsEnabled)
            XCTAssertEqual(config.explicitKillSwitches, [.bitcoinSend: false])
        }
    }

    func testSolanaVeto_whenDecoded_thenOnlySolanaSendIsVetoed() throws {
        for decoder in Self.decoders {
            let config = try decode(#"{"solana_send_enabled":false}"#, with: decoder)

            XCTAssertTrue(config.bitcoinSendEnabled)
            XCTAssertFalse(config.solanaSendEnabled)
            XCTAssertEqual(config.explicitKillSwitches, [.solanaSend: false])
        }
    }

    func testExplicitTrue_whenDecoded_thenItIsRecordedAsExplicitSoItCanLiftAVeto() throws {
        for decoder in Self.decoders {
            let config = try decode(
                #"{"bitcoin_send_enabled":true,"solana_send_enabled":true,"polkaswap_mutations_enabled":true}"#,
                with: decoder
            )

            XCTAssertEqual(
                config.explicitKillSwitches,
                [.bitcoinSend: true, .solanaSend: true, .polkaswapMutations: true]
            )
        }
    }

    func testEmergencyVetoTemplate_whenDecoded_thenPausesEveryShippedFundMovingFeature() throws {
        for decoder in Self.decoders {
            let config = try decode(Self.emergencyVetoTemplate, with: decoder)

            XCTAssertFalse(config.bitcoinSendEnabled)
            XCTAssertFalse(config.solanaSendEnabled)
            XCTAssertFalse(config.polkaswapMutationsEnabled)
            XCTAssertFalse(config.demeterMutationsEnabled)
            XCTAssertEqual(
                config.explicitKillSwitches,
                [.bitcoinSend: false, .solanaSend: false, .polkaswapMutations: false]
            )
        }
        // The production decoder (snake case) keeps reading the legacy fields unchanged.
        let production = try decode(Self.emergencyVetoTemplate, with: GithubJSONDecoder())
        XCTAssertEqual(production.pendulumCaseEnabled, false)
        XCTAssertEqual(production.nftEnabled, false)
    }

    func testRemoteTrue_whenDecoded_thenNewMutationFlagsKeepTheirExistingMeaning() throws {
        for decoder in Self.decoders {
            let config = try decode(
                #"{"bitcoin_send_enabled":true,"crossChainMutationsEnabled":false,"mutation_authorization":"token"}"#,
                with: decoder
            )

            XCTAssertTrue(config.bitcoinSendEnabled)
            XCTAssertFalse(config.crossChainMutationsEnabled)
            XCTAssertFalse(config.polkamarktMutationsEnabled)
            XCTAssertTrue(config.assetDiscoveryShadowMode)
            XCTAssertEqual(config.signedMutationAuthorization, "token")
        }
    }

    func testNonBooleanKillSwitch_whenDecoded_thenWholeDocumentIsRejected() {
        // A rejected document takes the failed-fetch path, which keeps remembered vetoes and
        // never enables anything (the shared template's "values" rule).
        for decoder in Self.decoders {
            XCTAssertThrowsError(try decode(#"{"bitcoin_send_enabled":"false"}"#, with: decoder))
            XCTAssertThrowsError(try decode(#"{"solana_send_enabled":"no"}"#, with: decoder))
        }
    }

    func testDefaultConfig_whenUsedAfterFailedFetch_thenStatesNoKillSwitch() {
        let config = FeatureToggleConfig.defaultConfig

        XCTAssertTrue(config.bitcoinSendEnabled)
        XCTAssertTrue(config.solanaSendEnabled)
        XCTAssertTrue(config.polkaswapMutationsEnabled)
        XCTAssertTrue(config.explicitKillSwitches.isEmpty)
    }

    func testDefaultConfig_whenUsedAfterFailedFetch_thenKeepsVetoedNftSendOff() {
        XCTAssertEqual(FeatureToggleConfig.defaultConfig.nftEnabled, false)
    }

    func testPreinstalledWalletImport_whenRemoteSaysTrue_thenStaysOff() throws {
        let payloads: [(String, JSONDecoder)] = [
            (#"{"pendulumCaseEnabled":true}"#, JSONDecoder()),
            (#"{"pendulum_case_enabled":true}"#, GithubJSONDecoder())
        ]
        for (payload, decoder) in payloads {
            let config = try decode(payload, with: decoder)

            XCTAssertEqual(config.pendulumCaseEnabled, true)
            XCTAssertFalse(PreinstalledWalletImportPolicy.isAvailable(remote: config))
        }
        XCTAssertFalse(PreinstalledWalletImportPolicy.isCompiledIn)
        // The compiled flag is the only gate the remote value is combined with.
        let remoteOn = FeatureToggleConfig(pendulumCaseEnabled: true, nftEnabled: nil)
        XCTAssertTrue(PreinstalledWalletImportPolicy.isAvailable(remote: remoteOn, isCompiledIn: true))
    }

    private static var decoders: [JSONDecoder] {
        [JSONDecoder(), GithubJSONDecoder()]
    }

    private func decode(_ json: String, with decoder: JSONDecoder) throws -> FeatureToggleConfig {
        try decoder.decode(FeatureToggleConfig.self, from: Data(json.utf8))
    }
}
