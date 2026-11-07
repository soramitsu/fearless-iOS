import FearlessWalletConnect
import Foundation
import SoraKeystore
import SSFCrypto
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

/// Real signatures over the live relay. The reference SDK dApp (`scripts/walletconnect/reference-dapp-sign.mjs`)
/// asks for `personal_sign`, `eth_signTypedData_v4` and `polkadot_signMessage` and checks every signature with code
/// that is not Fearless's. This side runs the app's own request preparation and signer, as the confirmation does
/// once the PIN is confirmed. Skipped unless `FEARLESS_WC_SIGN_LIVE=1`; it reads `FEARLESS_WC_EXCHANGE` and
/// `WALLETCONNECT_PROJECT_ID` (pass them as `TEST_RUNNER_` variables).
final class WalletConnectLiveSigningTests: XCTestCase {
    private static let polkadotBlockchain = "polkadot:91b171bb158e2d3848fa23a9f1c25182"

    func testTheAppSignsWhatTheReferenceDAppChecks() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["FEARLESS_WC_SIGN_LIVE"] == "1" else {
            throw XCTSkip("Set FEARLESS_WC_SIGN_LIVE=1 and run scripts/walletconnect/reference-dapp-sign.mjs first")
        }
        let exchange = URL(fileURLWithPath: try XCTUnwrap(environment["FEARLESS_WC_EXCHANGE"]))
        let projectId = try XCTUnwrap(environment["WALLETCONNECT_PROJECT_ID"])
        let relay = environment["WALLETCONNECT_RELAY_URL"].flatMap(URL.init(string:)) ??
            WalletConnectClient.Configuration.defaultRelayURL

        let keystore = InMemoryKeychain()
        let evm = try WalletConnectTestFixtures.ethereumWallet(seed: 0x5A, keystore: keystore)
        let polkadot = try Self.ed25519Wallet(seed: 0x5B, keystore: keystore)
        let chains = [WalletConnectTestFixtures.ethereumChain(), WalletConnectTestFixtures.polkadot()]
        let polkadotAddress = try polkadot.accountId.toAddress(using: .substrate(0))

        let store = InMemoryWalletConnectStore()
        let client = WalletConnectClient(
            configuration: .init(
                projectId: projectId,
                relayURL: relay,
                metadata: AppMetadata.createFearlessMetadata(),
                bundleId: Bundle.main.bundleIdentifier,
                userAgent: "wc-2/fearless-wallet-ios-signing-check"
            ),
            stateStore: store,
            secretStore: store
        )
        let recorder = LiveSigningRecorder()
        let service = WalletConnectServiceImpl(
            signingPolicy: .production,
            clientFactory: { _ in client },
            notificationCenter: NotificationCenter()
        )
        service.set(listener: recorder)
        service.setup()
        try runLive { await service.startTask?.value }

        let uri = try waitForFile(exchange.appendingPathComponent("uri-sign.txt"), timeout: 120)
        try runLive { try await service.connect(uri: uri) }

        try spin(timeout: 120) { recorder.proposal != nil }
        let proposal = try XCTUnwrap(recorder.proposal)
        let evmAccount = try XCTUnwrap(Account(blockchain: XCTUnwrap(Blockchain("eip155:1")), address: evm.addressHex))
        let polkadotAccount = try XCTUnwrap(
            Account(blockchain: XCTUnwrap(Blockchain(Self.polkadotBlockchain)), address: polkadotAddress)
        )
        let namespaces: [String: SessionNamespace] = [
            "eip155": SessionNamespace(
                chains: [evmAccount.blockchain],
                accounts: [evmAccount],
                methods: ["personal_sign", "eth_signTypedData_v4"],
                events: ["chainChanged", "accountsChanged"]
            ),
            "polkadot": SessionNamespace(
                chains: [polkadotAccount.blockchain],
                accounts: [polkadotAccount],
                methods: ["polkadot_signMessage"],
                events: []
            )
        ]
        try runLive { try await service.submit(proposalDecision: .approve(proposal: proposal, namespaces: namespaces)) }

        // What the confirmation does after the PIN: prepare (bind the account, check the network, decode), sign, send.
        let preparer = WalletConnectRequestPreparer()
        let signer = WalletConnectSignerImpl(policy: .production, keystore: keystore)
        var methods: [String] = []
        while methods.count < 3 {
            try spin(timeout: 180) { recorder.requests.count > methods.count }
            let request = recorder.requests[methods.count]
            let session = try XCTUnwrap(service.getSessions().first { $0.topic == request.topic })
            let prepared = try runLive {
                try await preparer.prepare(
                    request: request,
                    session: session,
                    wallets: [evm.wallet, polkadot.wallet],
                    chains: chains
                )
            }
            let signature = try runLive { try await signer.sign(request: prepared) }
            try runLive { try await service.submit(signDecision: .signed(request: request, signature: signature)) }
            methods.append(request.method)
        }
        XCTAssertEqual(methods, ["personal_sign", "eth_signTypedData_v4", "polkadot_signMessage"])

        let result = try waitForFile(exchange.appendingPathComponent("result.json"), timeout: 180)
        let parsed = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any])
        XCTAssertEqual(parsed["ok"] as? Bool, true, result)
        try JSONSerialization.data(
            withJSONObject: ["methods": methods, "evmAccount": evm.addressHex, "polkadotAccount": polkadotAddress],
            options: [.sortedKeys, .prettyPrinted]
        ).write(to: exchange.appendingPathComponent("wallet.json"))
        service.throttle()
    }

    // MARK: - Helpers

    /// A Polkadot account with an ed25519 key, stored as the signer reads it (the 32-byte seed), so the dApp can check
    /// its signatures without an sr25519 implementation.
    private static func ed25519Wallet(
        seed: UInt8,
        keystore: KeystoreProtocol
    ) throws -> (wallet: fearless.MetaAccountModel, accountId: Data) {
        let secret = Data(repeating: seed, count: 32)
        let publicKey = try Ed25519KeypairFactory().createKeypairFromSeed(secret, chaincodeList: []).publicKey().rawData()
        let wallet = fearless.MetaAccountModel(
            metaId: UUID().uuidString,
            name: "Polkadot ed25519 wallet",
            substrateAccountId: publicKey,
            substrateCryptoType: CryptoType.ed25519.rawValue,
            substratePublicKey: publicKey,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            assetKeysOrder: nil,
            canExportEthereumMnemonic: false,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: true,
            favouriteChainIds: []
        )
        try keystore.addKey(secret, with: fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: nil))
        return (wallet, publicKey)
    }

    private func waitForFile(_ url: URL, timeout: TimeInterval) throws -> String {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if let text = try? String(contentsOf: url), !text.isEmpty {
                return text
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        }
        throw XCTSkip("\(url.lastPathComponent) did not appear: is the reference dApp running?")
    }

    private func spin(timeout: TimeInterval, _ condition: () -> Bool) throws {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        XCTAssertTrue(condition(), "timed out")
    }

    private func runLive<T>(timeout: TimeInterval = 120, _ operation: @escaping () async throws -> T) throws -> T {
        let box = LiveSigningResultBox<T>()
        Task {
            do {
                box.result = .success(try await operation())
            } catch {
                box.result = .failure(error)
            }
        }
        let deadline = Date(timeIntervalSinceNow: timeout)
        while box.result == nil, Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        guard let result = box.result else {
            throw CancellationError()
        }
        return try result.get()
    }
}

private final class LiveSigningResultBox<T> {
    var result: Result<T, Error>?
}

private final class LiveSigningRecorder: WalletConnectServiceDelegate {
    private(set) var proposal: Session.Proposal?
    private(set) var requests: [Request] = []

    func session(proposal: Session.Proposal, verification _: WalletConnectVerification) {
        self.proposal = proposal
    }

    func sign(request: Request, session _: Session?, verification _: WalletConnectVerification) {
        requests.append(request)
    }
}
