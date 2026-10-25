import RobinHood
import SSFNetwork
import XCTest
@testable import fearless

/// Bitcoin and Solana sends ship enabled in 4.2.0; the remote feature_toggle may only veto
/// them, and a veto (also Polkaswap's, critique G4/T-10) survives restarts and failed fetches
/// until an explicit `true`.
final class UniversalSendReleasePolicyTests: XCTestCase {
    private var defaultsSuiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "UniversalSendReleasePolicyTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        MultiChainFeaturePolicy.liftRememberedVetoes()
    }

    override func tearDown() {
        MultiChainFeaturePolicy.liftRememberedVetoes()
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults = nil
        super.tearDown()
    }

    func testProductionDefaults_whenNoRemoteVeto_thenBitcoinAndSolanaSendAreEnabled() {
        XCTAssertTrue(UniversalSendReleasePolicy.production.isBitcoinEnabled)
        XCTAssertTrue(UniversalSendReleasePolicy.production.isSolanaEnabled)
        XCTAssertTrue(UniversalSendGate.production.isEnabled(.bitcoin))
        XCTAssertTrue(UniversalSendGate.production.isEnabled(.solana))
        XCTAssertNoThrow(try UniversalSendGate.production.requireTransfer(on: .bitcoin))
        XCTAssertNoThrow(try UniversalSendGate.production.requireTransfer(on: .solana))
    }

    func testRemoteVetoFalse_whenCompiledOn_thenBlocksOnlyTheVetoedNetwork() throws {
        try MultiChainFeaturePolicy.update(decode(#"{"bitcoin_send_enabled":false}"#))

        XCTAssertFalse(UniversalSendGate.production.isEnabled(.bitcoin))
        XCTAssertTrue(UniversalSendGate.production.isEnabled(.solana))
        XCTAssertThrowsError(try UniversalSendGate.production.requireTransfer(on: .bitcoin)) { error in
            guard case TransferServiceError.bitcoinSendPaused = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    #if DEBUG
        func testRemoteTrue_whenCompiledOff_thenCannotEnableSend() throws {
            let compiledOff = UniversalSendReleasePolicy.compiledForTests(isBitcoinEnabled: false, isSolanaEnabled: false)
            let remoteTrue = try decode(#"{"bitcoin_send_enabled":true,"solana_send_enabled":true}"#)
            let gate = UniversalSendGate(policy: compiledOff, remoteConfig: { remoteTrue })

            XCTAssertFalse(gate.isEnabled(.bitcoin))
            XCTAssertFalse(gate.isEnabled(.solana))
            XCTAssertThrowsError(try gate.requireTransfer(on: .solana)) { error in
                guard case TransferServiceError.solanaSendPaused = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
        }
    #endif

    func testStoredVeto_whenLaterFetchFails_thenVetoSurvives() throws {
        try MultiChainFeaturePolicy.update(decode(#"{"bitcoin_send_enabled":false,"solana_send_enabled":false}"#))

        // FeatureToggleProvider.handleDefault delivers the default config on any failed fetch.
        MultiChainFeaturePolicy.update(.defaultConfig)

        XCTAssertFalse(MultiChainFeaturePolicy.current.bitcoinSendEnabled)
        XCTAssertFalse(MultiChainFeaturePolicy.current.solanaSendEnabled)
        XCTAssertFalse(UniversalSendGate.production.isEnabled(.bitcoin))
    }

    func testStoredVeto_whenAppRelaunchesOffline_thenVetoSurvives() {
        RemoteKillSwitchStore(defaults: defaults).record([.solanaSend: false, .bitcoinSend: true])

        // A new process reads the same defaults before any fetch completes.
        let relaunched = RemoteKillSwitchStore(defaults: defaults)

        XCTAssertEqual(relaunched.vetoes, [.solanaSend])
    }

    func testSuccessfulFetchWithoutKey_whenVetoRemembered_thenVetoStays() throws {
        try MultiChainFeaturePolicy.update(decode(#"{"bitcoin_send_enabled":false}"#))

        try MultiChainFeaturePolicy.update(decode(#"{"pendulum_case_enabled":false,"nft_enabled":false,"dapp_enabled":false}"#))

        XCTAssertFalse(MultiChainFeaturePolicy.current.bitcoinSendEnabled)
    }

    func testExplicitTrue_whenVetoRemembered_thenVetoIsLifted() throws {
        try MultiChainFeaturePolicy.update(decode(#"{"bitcoin_send_enabled":false,"polkaswap_mutations_enabled":false}"#))

        try MultiChainFeaturePolicy.update(decode(#"{"bitcoin_send_enabled":true}"#))

        XCTAssertTrue(MultiChainFeaturePolicy.current.bitcoinSendEnabled)
        XCTAssertFalse(MultiChainFeaturePolicy.current.polkaswapMutationsEnabled)
    }

    func testStore_whenExplicitValuesArrive_thenOnlyFalseIsPersistedAndTrueRemovesIt() {
        let store = RemoteKillSwitchStore(defaults: defaults)

        store.record([.bitcoinSend: false, .polkaswapMutations: false])
        store.record([.bitcoinSend: true])
        store.record([:])

        XCTAssertEqual(store.vetoes, [.polkaswapMutations])
        XCTAssertNil(defaults.object(forKey: RemoteKillSwitch.bitcoinSend.storageKey))
        XCTAssertEqual(defaults.object(forKey: RemoteKillSwitch.polkaswapMutations.storageKey) as? Bool, false)
    }

    func testPolkaswapVeto_whenLaterFetchFails_thenVetoSurvives() throws {
        try MultiChainFeaturePolicy.update(decode(#"{"polkaswap_mutations_enabled":false}"#))

        MultiChainFeaturePolicy.update(.defaultConfig)

        XCTAssertFalse(MultiChainFeaturePolicy.current.polkaswapMutationsEnabled)
        XCTAssertTrue(MultiChainFeaturePolicy.current.bitcoinSendEnabled)
    }

    func testUpgradeFromStoreBuild_whenNoKillSwitchWasEverStored_thenOfflineFirstLaunchKeepsEverythingOn() {
        // App Store 4.0.4 and earlier never wrote these keys; unrelated or malformed values
        // must not read as a veto on the first offline launch of 4.2.0.
        defaults.set(true, forKey: "feature.kill_switch.unknown")
        defaults.set("false", forKey: RemoteKillSwitch.bitcoinSend.storageKey)
        defaults.set(true, forKey: RemoteKillSwitch.solanaSend.storageKey)

        XCTAssertTrue(RemoteKillSwitchStore(defaults: defaults).vetoes.isEmpty)
        MultiChainFeaturePolicy.update(.defaultConfig)
        XCTAssertTrue(MultiChainFeaturePolicy.current.bitcoinSendEnabled)
        XCTAssertTrue(MultiChainFeaturePolicy.current.solanaSendEnabled)
        XCTAssertTrue(MultiChainFeaturePolicy.current.polkaswapMutationsEnabled)
    }

    func testFeatureToggleProvider_whenFetchFailsAfterVeto_thenVetoSurvives() throws {
        _ = try fetch(through: Data(#"{"bitcoin_send_enabled":false,"polkaswap_mutations_enabled":false}"#.utf8))
        XCTAssertFalse(MultiChainFeaturePolicy.current.bitcoinSendEnabled)

        for failedPayload in [Data("{".utf8), Data("null".utf8), Data(#"{"bitcoin_send_enabled":"true"}"#.utf8)] {
            let delivered = try fetch(through: failedPayload)

            XCTAssertTrue(delivered.explicitKillSwitches.isEmpty)
            XCTAssertFalse(MultiChainFeaturePolicy.current.bitcoinSendEnabled)
            XCTAssertFalse(MultiChainFeaturePolicy.current.polkaswapMutationsEnabled)
            XCTAssertTrue(MultiChainFeaturePolicy.current.solanaSendEnabled)
        }

        _ = try fetch(through: Data(#"{"bitcoin_send_enabled":true,"polkaswap_mutations_enabled":true}"#.utf8))
        XCTAssertTrue(MultiChainFeaturePolicy.current.bitcoinSendEnabled)
        XCTAssertTrue(MultiChainFeaturePolicy.current.polkaswapMutationsEnabled)
    }

    // MARK: - Helpers

    private func decode(_ json: String) throws -> FeatureToggleConfig {
        try GithubJSONDecoder().decode(FeatureToggleConfig.self, from: Data(json.utf8))
    }

    private func fetch(through payload: Data) throws -> FeatureToggleConfig {
        let provider = FeatureToggleProvider(
            networkOperationFactory: StaticPayloadNetworkOperationFactory(payload: payload),
            operationQueue: OperationQueue()
        )
        let operation = provider.fetchConfigOperation()
        let completion = expectation(description: "feature toggle fetch completes")
        operation.completionBlock = {
            completion.fulfill()
        }
        OperationQueue().addOperation(operation)
        wait(for: [completion], timeout: 3)

        switch operation.result {
        case let .success(config):
            return config
        case let .failure(error):
            throw error
        case .none:
            throw ProviderFetchError.missingResult
        }
    }
}

extension MultiChainFeaturePolicy {
    /// Lifts every remembered veto through the real remote-config path (an explicit `true`
    /// for each kill switch), so a test never leaves a veto behind in the host app's defaults.
    static func liftRememberedVetoes() {
        update(FeatureToggleConfig(
            pendulumCaseEnabled: false,
            nftEnabled: true,
            explicitKillSwitches: Dictionary(uniqueKeysWithValues: RemoteKillSwitch.allCases.map { ($0, true) })
        ))
        update(.defaultConfig)
    }
}

private enum ProviderFetchError: Error {
    case missingResult
}

private final class StaticPayloadNetworkOperationFactory: NetworkOperationFactoryProtocol {
    private let payload: Data

    init(payload: Data) {
        self.payload = payload
    }

    func fetchData<T: Decodable>(from _: URL) -> BaseOperation<T> {
        ClosureOperation {
            try GithubJSONDecoder().decode(T.self, from: self.payload)
        }
    }
}
