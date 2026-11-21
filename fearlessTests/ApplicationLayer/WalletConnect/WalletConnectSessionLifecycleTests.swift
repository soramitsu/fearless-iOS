import FearlessWalletConnect
import Foundation
import SoraKeystore
import SSFModels
import XCTest
@testable import fearless

/// Forgetting a wallet ends every session that granted one of its accounts, logging out ends every session and
/// pairing, and a request is bound only to the chain its CAIP-2 reference names exactly.
final class WalletConnectSessionLifecycleTests: XCTestCase {
    private typealias Fixtures = WalletConnectTestFixtures

    // MARK: - Forgetting a wallet

    func testForgetWallet_endsEverySessionThatGrantedOneOfItsAccounts() async throws {
        let keystore = InMemoryKeychain()
        let ethereum = try Fixtures.ethereumWallet(seed: 0x21, keystore: keystore)
        let other = try Fixtures.ethereumWallet(seed: 0x22, keystore: keystore)
        let mainnet = try Fixtures.ethereumBlockchain()
        let bsc = try Fixtures.ethereumBlockchain("56")
        let service = WalletConnectServiceSpy()
        service.sessions = [
            try Fixtures.session(topic: "first", approving: [(mainnet, ethereum.addressHex)]),
            // Granted on another chain only: before, only sessions matching a required chain were found.
            try Fixtures.session(topic: "second", approving: [(bsc, ethereum.addressHex.lowercased())]),
            try Fixtures.session(topic: "someone-else", approving: [(mainnet, other.addressHex)])
        ]

        try await WalletConnectDisconnectServiceImpl(walletConnectService: service).disconnect(wallet: ethereum.wallet)

        XCTAssertEqual(Set(service.disconnectedTopics), ["first", "second"])
    }

    func testForgetWallet_matchesSubstrateAccountsWhateverPrefixTheSessionUsed() throws {
        let keystore = InMemoryKeychain()
        let substrate = try Fixtures.substrateWallet(seed: 0x23, keystore: keystore)
        let polkadot = try Fixtures.polkadotBlockchain()
        let westend = try Fixtures.westendBlockchain()
        let sessions = [
            try Fixtures.session(topic: "polkadot", approving: [(polkadot, substrate.accountId.toAddress(using: .substrate(0)))]),
            try Fixtures.session(topic: "westend", approving: [(westend, substrate.accountId.toAddress(using: .substrate(42)))]),
            try Fixtures.session(
                topic: "unrelated",
                approving: [(polkadot, Data(repeating: 0x77, count: 32).toAddress(using: .substrate(0)))]
            )
        ]

        let matched = WalletConnectWalletSessions.sessions(sessions, grantingAccountsOf: substrate.wallet)

        XCTAssertEqual(Set(matched.map(\.topic)), ["polkadot", "westend"])
    }

    func testForgetWallet_whenOneDAppCannotBeTold_thenTheOthersStillEnd() async throws {
        let keystore = InMemoryKeychain()
        let ethereum = try Fixtures.ethereumWallet(seed: 0x24, keystore: keystore)
        let mainnet = try Fixtures.ethereumBlockchain()
        let service = FailingDisconnectService(failing: "first")
        service.sessions = [
            try Fixtures.session(topic: "first", approving: [(mainnet, ethereum.addressHex)]),
            try Fixtures.session(topic: "second", approving: [(mainnet, ethereum.addressHex)])
        ]

        do {
            try await WalletConnectDisconnectServiceImpl(walletConnectService: service).disconnect(wallet: ethereum.wallet)
            XCTFail("The failure must be reported")
        } catch {}

        XCTAssertEqual(Set(service.attempts), ["first", "second"])
    }

    func testLogout_endsEverySessionAndPairing() {
        let service = WalletConnectServiceSpy()

        WalletConnectDisconnectServiceImpl(walletConnectService: service).disconnectAllSessions()

        let deadline = Date(timeIntervalSinceNow: 3)
        while service.disconnectAllCalls == 0, Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        XCTAssertEqual(service.disconnectAllCalls, 1)
        XCTAssertTrue(service.disconnectedTopics.isEmpty)
    }

    func testLogoutBeforeWalletConnectWasSetUp_stillReachesItsRecord() async throws {
        let made = ClientCounter()
        let service = WalletConnectServiceImpl(
            clientFactory: { _ in
                made.count += 1
                let store = InMemoryWalletConnectStore()
                return WalletConnectClient(
                    configuration: .init(
                        projectId: "offline",
                        metadata: AppMetadata(name: "Fearless", description: "", url: "https://fearlesswallet.io", icons: []),
                        bundleId: nil,
                        userAgent: "wc-2/fearless-wallet-ios-tests"
                    ),
                    stateStore: store,
                    secretStore: store,
                    transportFactory: OfflineRelayTransportFactory()
                )
            },
            notificationCenter: NotificationCenter()
        )

        // The client is made for the clean-up, without starting it; setup() later uses the same one.
        try await service.disconnectAll()

        XCTAssertEqual(made.count, 1)
        XCTAssertNotNil(service.client)
        XCTAssertNil(service.startTask)
    }

    func testWalletAccountIds_includeTheSubstrateEthereumAndChainAccounts() throws {
        let keystore = InMemoryKeychain()
        let substrate = try Fixtures.substrateWallet(seed: 0x25, keystore: keystore)
        let ethereum = try Fixtures.ethereumWallet(seed: 0x26, keystore: keystore)

        XCTAssertTrue(WalletConnectWalletSessions.accountIds(of: substrate.wallet).contains(substrate.accountId))
        XCTAssertTrue(
            WalletConnectWalletSessions.accountIds(of: ethereum.wallet).contains(try Data(hexStringSSF: ethereum.addressHex))
        )
    }

    // MARK: - Exact chain references

    func testPolkadotChain_matchesOnlyTheExact32CharacterReference() {
        let polkadot = Fixtures.polkadot()
        let reference = String(Fixtures.polkadotGenesis.prefix(32))

        XCTAssertTrue(polkadot.match(Caip2ChainId(namespace: "polkadot", reference: reference)))
        // A shorter reference would match every chain whose genesis hash starts with it.
        XCTAssertFalse(polkadot.match(Caip2ChainId(namespace: "polkadot", reference: String(reference.prefix(31)))))
        XCTAssertFalse(polkadot.match(Caip2ChainId(namespace: "polkadot", reference: "9")))
        XCTAssertFalse(polkadot.match(Caip2ChainId(namespace: "polkadot", reference: "")))
        XCTAssertFalse(polkadot.match(Caip2ChainId(namespace: "polkadot", reference: Fixtures.polkadotGenesis)))
        XCTAssertFalse(polkadot.match(Caip2ChainId(namespace: "polkadot", reference: reference.uppercased())))
        XCTAssertFalse(polkadot.match(Caip2ChainId(namespace: "eip155", reference: reference)))
    }

    func testRequestForAShortenedReference_isNotBoundToAnyChain() throws {
        let factory = WalletConnectModelFactoryImpl()
        let chains = [Fixtures.polkadot(), Fixtures.westend()]
        let shortened = try XCTUnwrap(Blockchain("polkadot:\(Fixtures.polkadotGenesis.prefix(8))"))

        XCTAssertTrue(factory.resolveChains(for: [shortened], chains: chains).isEmpty)
        XCTAssertEqual(
            factory.resolveChains(for: [try Fixtures.polkadotBlockchain()], chains: chains).map(\.chainId),
            [Fixtures.polkadotGenesis]
        )
    }
}

private final class ClientCounter: @unchecked Sendable {
    var count = 0
}

/// Fails to tell one dApp; records every attempt.
private final class FailingDisconnectService: WalletConnectService {
    private let failing: String
    private(set) var attempts: [String] = []
    var sessions: [Session] = []

    init(failing: String) {
        self.failing = failing
    }

    func setup() {}
    func throttle() {}
    func set(listener _: WalletConnectServiceDelegate) {}
    func connect(uri _: String) async throws {}

    func disconnect(topic: String) async throws {
        attempts.append(topic)
        if topic == failing {
            throw WalletConnectServiceError.unavailable
        }
    }

    func disconnectAll() async throws {}

    func getSessions() -> [Session] {
        sessions
    }

    func isPending(request _: Request) async -> Bool {
        true
    }

    func legacySessionsNeedingReconnect() -> [WalletConnectLegacySession] {
        []
    }

    func submit(proposalDecision _: WalletConnectProposalDecision) async throws {}
    func submit(signDecision _: WalletConnectSignDecision) async throws {}
}
