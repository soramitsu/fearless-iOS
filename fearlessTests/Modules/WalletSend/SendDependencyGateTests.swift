import XCTest
import BigInt
import IrohaCrypto
import RobinHood
import SoraFoundation
import SoraKeystore
import SSFModels
import SSFUtils
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif
@testable import fearless

/// A Bitcoin/Solana veto is enforced where Send routes the network (before account lookup,
/// cache access or transport construction) and again inside `submit`, so a veto that
/// arrives after the fee quote still prevents key access, signing and broadcast.
final class SendDependencyGateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MultiChainFeaturePolicy.liftRememberedVetoes()
    }

    override func tearDown() {
        MultiChainFeaturePolicy.liftRememberedVetoes()
        super.tearDown()
    }

    func testPrepareDependencies_whenBitcoinPaused_thenThrowsPausedBeforeAccountLookup() async {
        let container = Self.productionContainer(wallet: AccountGenerator.generateMetaAccount())
        MultiChainFeaturePolicy.update(Self.vetoConfig(bitcoin: false))

        for chainId in [UniversalWalletRegistry.bitcoinMainnet.chainId, UniversalWalletRegistry.bitcoinTestnet.id] {
            do {
                _ = try await container.prepareDepencies(chainAsset: Self.chainAsset(chainId: chainId, asset: Self.btcAsset))
                XCTFail("Expected paused Bitcoin routing for \(chainId)")
            } catch let error as UniversalWalletSendRoutingError {
                XCTAssertEqual(error, .bitcoinSendPaused)
            } catch {
                XCTFail("Expected the veto before account lookup for \(chainId), got \(error)")
            }
        }
    }

    func testPrepareDependencies_whenSolanaPaused_thenThrowsPausedBeforeAccountLookup() async {
        let container = Self.productionContainer(wallet: AccountGenerator.generateMetaAccount())
        MultiChainFeaturePolicy.update(Self.vetoConfig(solana: false))

        for chainId in [UniversalWalletRegistry.solanaMainnet.chainId, UniversalWalletRegistry.solanaDevnet.id] {
            do {
                _ = try await container.prepareDepencies(chainAsset: Self.chainAsset(chainId: chainId, asset: Self.solAsset))
                XCTFail("Expected paused Solana routing for \(chainId)")
            } catch let error as UniversalWalletSendRoutingError {
                XCTAssertEqual(error, .solanaSendPaused)
            } catch {
                XCTFail("Expected the veto before account lookup for \(chainId), got \(error)")
            }
        }
    }

    func testPrepareDependencies_whenOnlyBitcoinIsVetoed_thenSolanaStillRoutes() async {
        let container = Self.productionContainer(wallet: AccountGenerator.generateMetaAccount())
        MultiChainFeaturePolicy.update(Self.vetoConfig(bitcoin: false))

        do {
            _ = try await container.prepareDepencies(
                chainAsset: Self.chainAsset(chainId: UniversalWalletRegistry.solanaMainnet.chainId, asset: Self.solAsset)
            )
            XCTFail("Expected the missing Solana account to be reported")
        } catch ChainAccountFetchingError.accountNotExists {
            // Routed past the gate to the ordinary account lookup.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPrepareDependencies_whenEnabledByDefault_thenRoutesBitcoinToGatedTransferService() async throws {
        let container = try Self.productionContainer(wallet: Self.walletWithBitcoinAccount())

        let dependencies = try await container.prepareDepencies(
            chainAsset: Self.chainAsset(chainId: UniversalWalletRegistry.bitcoinMainnet.chainId, asset: Self.btcAsset)
        )

        XCTAssertTrue(dependencies.transferService is BitcoinTransferService)
    }

    func testPrepareDependencies_whenVetoArrivesAfterRouting_thenCachedServiceIsNotReturned() async throws {
        let container = try Self.productionContainer(wallet: Self.walletWithBitcoinAccount())
        let chainAsset = Self.chainAsset(chainId: UniversalWalletRegistry.bitcoinMainnet.chainId, asset: Self.btcAsset)
        _ = try await container.prepareDepencies(chainAsset: chainAsset)

        MultiChainFeaturePolicy.update(Self.vetoConfig(bitcoin: false))

        do {
            _ = try await container.prepareDepencies(chainAsset: chainAsset)
            XCTFail("Expected the cached Bitcoin service to be withheld after a veto")
        } catch let error as UniversalWalletSendRoutingError {
            XCTAssertEqual(error, .bitcoinSendPaused)
        }
    }

    func testBitcoinSubmit_whenVetoArrivesAfterQuote_thenNoKeyAccessOrBroadcast() async throws {
        let wallet = try Self.walletWithBitcoinAccount()
        let chain = Self.chain(chainId: UniversalWalletRegistry.bitcoinMainnet.chainId, asset: Self.btcAsset)
        let client = BitcoinIndexerClientSpy()
        let mnemonicProvider = CountingMnemonicProvider(mnemonic: Self.mnemonic)
        let remoteConfig = RemoteConfigBox(.defaultConfig)
        let service = BitcoinTransferService(
            wallet: wallet,
            chain: chain,
            client: client,
            mnemonicProvider: mnemonicProvider,
            sendGate: UniversalSendGate(policy: .production, remoteConfig: { remoteConfig.config })
        )
        let transfer = Self.bitcoinTransfer(chain: chain)

        let fee = try await service.estimateFee(for: transfer)
        let mnemonicReadsAfterQuote = mnemonicProvider.callCount
        remoteConfig.config = Self.vetoConfig(bitcoin: false)

        do {
            _ = try await service.submit(transfer: transfer)
            XCTFail("Expected the vetoed Bitcoin transfer to stop before broadcast")
        } catch TransferServiceError.bitcoinSendPaused {
            // Expected.
        }

        XCTAssertGreaterThan(fee, .zero)
        XCTAssertEqual(client.broadcastCallCount, 0)
        XCTAssertEqual(mnemonicProvider.callCount, mnemonicReadsAfterQuote)
    }

    func testBitcoinSubmit_whenNotVetoed_thenBroadcastsOnce() async throws {
        let wallet = try Self.walletWithBitcoinAccount()
        let chain = Self.chain(chainId: UniversalWalletRegistry.bitcoinMainnet.chainId, asset: Self.btcAsset)
        let client = BitcoinIndexerClientSpy()
        let service = BitcoinTransferService(
            wallet: wallet,
            chain: chain,
            client: client,
            mnemonicProvider: CountingMnemonicProvider(mnemonic: Self.mnemonic),
            sendGate: UniversalSendGate(policy: .production, remoteConfig: { .defaultConfig })
        )
        let transfer = Self.bitcoinTransfer(chain: chain)

        _ = try await service.estimateFee(for: transfer)
        let txid = try await service.submit(transfer: transfer)

        XCTAssertEqual(client.broadcastCallCount, 1)
        XCTAssertEqual(txid, Self.expectedBitcoinTxid)
    }

    func testSolanaSubmit_whenVetoed_thenNoKeyAccessRpcOrBroadcast() async throws {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = AccountGenerator.generateMetaAccount(with: [
            ChainAccountModel(
                chainId: UniversalWalletRegistry.solanaMainnet.chainId,
                accountId: account.publicKey,
                publicKey: account.publicKey,
                cryptoType: CryptoType.ed25519.rawValue,
                ethereumBased: false
            )
        ])
        let chain = Self.chain(chainId: UniversalWalletRegistry.solanaMainnet.chainId, asset: Self.solAsset)
        let rpc = SolanaRpcClientSpy()
        let mnemonicProvider = CountingMnemonicProvider(mnemonic: Self.mnemonic)
        let service = try SolanaTransferService(
            wallet: wallet,
            chain: chain,
            rpcClient: rpc,
            mnemonicProvider: mnemonicProvider,
            sendGate: UniversalSendGate(policy: .production, remoteConfig: { Self.vetoConfig(solana: false) })
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.solAsset),
            amount: BigUInt(1_000_000),
            receiver: Self.solanaRecipient,
            tip: nil,
            appId: nil
        )

        do {
            _ = try await service.submit(transfer: transfer)
            XCTFail("Expected the vetoed Solana transfer to stop before signing")
        } catch TransferServiceError.solanaSendPaused {
            // Expected.
        }

        XCTAssertEqual(rpc.callCount, 0)
        XCTAssertEqual(mnemonicProvider.callCount, 0)
    }

    // MARK: - Helpers

    private static func productionContainer(wallet: MetaAccountModel) -> SendDepencyContainer {
        SendDepencyContainer(
            wallet: wallet,
            operationManager: fearless.OperationManagerFacade.sharedManager
        )
    }

    private static func vetoConfig(bitcoin: Bool = true, solana: Bool = true) -> FeatureToggleConfig {
        var explicit: [RemoteKillSwitch: Bool] = [:]
        if !bitcoin {
            explicit[.bitcoinSend] = false
        }
        if !solana {
            explicit[.solanaSend] = false
        }
        return FeatureToggleConfig(
            pendulumCaseEnabled: false,
            nftEnabled: true,
            bitcoinSendEnabled: bitcoin,
            solanaSendEnabled: solana,
            explicitKillSwitches: explicit
        )
    }

    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    fileprivate static let bitcoinSource = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
    fileprivate static let expectedBitcoinTxid = "94c9b9d5070f24e06725b1000d9b1a0d46473d07b59088aca35e3d3da345023d"
    private static let bitcoinRecipient = "bc1qslk39wvggqa0vl8nd6jckaz54dw3vk45c5w60m"
    private static let solanaRecipient = "9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM"
    private static let btcAsset = AssetModel(
        id: "BTC",
        name: "Bitcoin",
        symbol: "BTC",
        precision: 8,
        isUtility: true,
        isNative: true
    )
    private static let solAsset = AssetModel(
        id: "SOL",
        name: "Solana",
        symbol: "SOL",
        precision: 9,
        isUtility: true,
        isNative: true
    )

    private static func walletWithBitcoinAccount() throws -> MetaAccountModel {
        let account = try BitcoinKeyDerivation.deriveAccount(mnemonic: mnemonic, network: .mainnet)
        return AccountGenerator.generateMetaAccount(with: [
            ChainAccountModel(
                chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
                accountId: account.publicKey,
                publicKey: account.publicKey,
                cryptoType: CryptoType.ecdsa.rawValue,
                ethereumBased: false
            )
        ])
    }

    private static func bitcoinTransfer(chain: ChainModel) -> Transfer {
        Transfer(
            chainAsset: ChainAsset(chain: chain, asset: btcAsset),
            amount: BigUInt(50000),
            receiver: bitcoinRecipient,
            tip: nil,
            appId: nil
        )
    }

    private static func chainAsset(chainId: String, asset: AssetModel) -> ChainAsset {
        ChainAsset(chain: chain(chainId: chainId, asset: asset), asset: asset)
    }

    private static func chain(chainId: String, asset: AssetModel) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: asset.name,
            assets: [asset],
            xcm: nil,
            nodes: [],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

private final class RemoteConfigBox {
    var config: FeatureToggleConfig

    init(_ config: FeatureToggleConfig) {
        self.config = config
    }
}

private final class CountingMnemonicProvider: BitcoinMnemonicProviding {
    private let mnemonic: String?
    private(set) var callCount = 0

    init(mnemonic: String?) {
        self.mnemonic = mnemonic
    }

    func mnemonic(for _: MetaAccountModel, chain _: ChainModel) throws -> String? {
        callCount += 1
        return mnemonic
    }
}

private final class BitcoinIndexerClientSpy: BitcoinIndexerClientProtocol {
    private(set) var broadcastCallCount = 0

    func address(address: String, network _: BitcoinIndexerNetwork, baseURL _: String?) async throws -> BitcoinEsploraAddress {
        let isFunded = address.lowercased() == SendDependencyGateTests.bitcoinSource
        return BitcoinEsploraAddress(
            address: address,
            chainStats: BitcoinEsploraStats(
                fundedTxoCount: isFunded ? 1 : 0,
                fundedTxoSum: isFunded ? 100_000 : 0,
                spentTxoCount: 0,
                spentTxoSum: 0,
                txCount: isFunded ? 1 : 0
            ),
            mempoolStats: BitcoinEsploraStats(
                fundedTxoCount: 0,
                fundedTxoSum: 0,
                spentTxoCount: 0,
                spentTxoSum: 0,
                txCount: 0
            )
        )
    }

    func utxos(address: String, network _: BitcoinIndexerNetwork, baseURL _: String?) async throws -> [BitcoinEsploraUtxo] {
        guard address.lowercased() == SendDependencyGateTests.bitcoinSource else {
            return []
        }
        return [
            BitcoinEsploraUtxo(
                txid: String(repeating: "11", count: 32),
                vout: 1,
                value: 100_000,
                status: BitcoinEsploraTxStatus(confirmed: true, blockHash: nil, blockHeight: nil, blockTime: nil)
            )
        ]
    }

    func transactions(
        address _: String,
        network _: BitcoinIndexerNetwork,
        baseURL _: String?,
        lastSeenTxid _: String?,
        mempool _: Bool
    ) async throws -> [BitcoinEsploraTransaction] {
        []
    }

    func feeEstimates(network _: BitcoinIndexerNetwork, baseURL _: String?) async throws -> [String: Double] {
        ["2": 2]
    }

    func broadcastTransaction(txHex _: String, network _: BitcoinIndexerNetwork, baseURL _: String?) async throws -> String {
        broadcastCallCount += 1
        // RFC6979 signing makes the transaction for this fixed UTXO, amount and fee rate
        // deterministic (the same vector as BitcoinSendServiceTests).
        return SendDependencyGateTests.expectedBitcoinTxid
    }
}

private final class SolanaRpcClientSpy: SolanaRpcClientProtocol {
    // Explicit protocol fixture binding; endpoint attestation is tested with actual clients separately.
    var expectedGenesisHash: String? = UniversalWalletRegistry.solanaMainnet.genesisHash
    func bound(toGenesisHash genesisHash: String) throws -> SolanaRpcClientProtocol {
        expectedGenesisHash = genesisHash
        return self
    }
    func verifyCluster(rpcURL _: String?) async throws { try Task.checkCancellation() }

    private(set) var callCount = 0

    func latestBlockhash(commitment _: SolanaRpcCommitment, rpcURL _: String?) async throws -> SolanaLatestBlockhashResponse {
        callCount += 1
        throw SolanaRpcClientSpyError.unexpectedCall
    }

    func feeForMessage(
        _: String,
        commitment _: SolanaRpcCommitment,
        rpcURL _: String?
    ) async throws -> SolanaFeeForMessageResponse {
        callCount += 1
        throw SolanaRpcClientSpyError.unexpectedCall
    }

    func minimumBalanceForRentExemption(
        dataLength _: Int,
        commitment _: SolanaRpcCommitment,
        rpcURL _: String?
    ) async throws -> Int64 {
        callCount += 1
        throw SolanaRpcClientSpyError.unexpectedCall
    }

    func accountExists(address _: String, commitment _: SolanaRpcCommitment, rpcURL _: String?) async throws -> Bool {
        callCount += 1
        throw SolanaRpcClientSpyError.unexpectedCall
    }

    func simulateTransaction(
        _: String,
        options _: SolanaSimulationOptions,
        rpcURL _: String?
    ) async throws -> SolanaSimulationResponse {
        callCount += 1
        throw SolanaRpcClientSpyError.unexpectedCall
    }

    func sendRawTransaction(_: String, options _: SolanaBroadcastOptions, rpcURL _: String?) async throws -> String {
        callCount += 1
        throw SolanaRpcClientSpyError.unexpectedCall
    }

    func accountInfo(address _: String, commitment _: SolanaRpcCommitment, rpcURL _: String?) async throws -> SolanaAccountInfo? {
        callCount += 1
        throw SolanaRpcClientSpyError.unexpectedCall
    }

    func balance(address _: String, commitment _: SolanaRpcCommitment, rpcURL _: String?) async throws -> Int64 {
        callCount += 1
        throw SolanaRpcClientSpyError.unexpectedCall
    }

    func tokenAccountsByOwner(
        owner _: String,
        programId _: String,
        commitment _: SolanaRpcCommitment,
        rpcURL _: String?
    ) async throws -> [SolanaParsedTokenAccount] {
        callCount += 1
        throw SolanaRpcClientSpyError.unexpectedCall
    }

    func signatureStatuses(_: [String], searchTransactionHistory _: Bool, rpcURL _: String?) async throws -> [SolanaSignatureStatus?] {
        callCount += 1
        throw SolanaRpcClientSpyError.unexpectedCall
    }

    func blockHeight(commitment _: SolanaRpcCommitment, rpcURL _: String?) async throws -> Int64 {
        callCount += 1
        throw SolanaRpcClientSpyError.unexpectedCall
    }

    func recentPrioritizationFees(accounts _: [String], rpcURL _: String?) async throws -> [Int64] {
        callCount += 1
        throw SolanaRpcClientSpyError.unexpectedCall
    }
}

private enum SolanaRpcClientSpyError: Error {
    case unexpectedCall
}

// MARK: - Local-chain end-to-end

/// Drives the real Bitcoin and Solana transfer services (planner, builder, signer, indexer and
/// RPC clients) against local private chains started by `scripts/test-local-chain-sends.sh`:
/// `bitcoind -regtest` behind an Esplora-compatible shim, and `solana-test-validator`. Skipped
/// when the runner's endpoints are absent; every request is confined to 127.0.0.1.
final class SendLocalChainE2ETests: XCTestCase {
    override func setUp() {
        super.setUp()
        // The release gate reads the process-wide remote config; start from no remembered veto
        // so "enabled by default" is what the build ships, not a leftover from another test.
        MultiChainFeaturePolicy.liftRememberedVetoes()
    }

    override func tearDown() {
        MultiChainFeaturePolicy.liftRememberedVetoes()
        super.tearDown()
    }

    func testBitcoinRegtestSend_whenEnabledByDefault_thenRecipientChangeAndFeeAreExactOnChain() async throws {
        let esplora = try LocalRegtestEsplora(baseURL: localEndpoint("FEARLESS_E2E_ESPLORA_URL"))
        let mnemonic = Self.bitcoinSenderMnemonic
        let sender = try BitcoinKeyDerivation.deriveAccount(mnemonic: mnemonic, network: .testnet)
        let recipient = try BitcoinKeyDerivation.deriveAccount(mnemonic: Self.recipientMnemonic, network: .testnet)
        let fundingTxid = try await esplora.fund(address: sender.firstReceiveAddress, sats: 1_000_000)
        let service = makeBitcoinService(mnemonic: mnemonic, publicKey: sender.publicKey, esplora: esplora)
        let transfer = Self.bitcoinTransfer(sats: 250_000, recipient: recipient.firstReceiveAddress)

        let quotedFee = try await service.estimateFee(for: transfer)
        let txid = try await service.submit(transfer: transfer)

        let mempool = try await esplora.mempool()
        XCTAssertTrue(mempool.contains(txid))
        _ = try await esplora.mine(blocks: 1)
        let transaction = try await esplora.transaction(txid)
        XCTAssertTrue(transaction.status.confirmed)
        XCTAssertEqual(transaction.vin.map(\.txid), [fundingTxid])
        XCTAssertEqual(transaction.fee, Int64(quotedFee))
        XCTAssertEqual(transaction.vout.count, 2)
        XCTAssertEqual(transaction.vout.first { $0.scriptpubkeyAddress == recipient.firstReceiveAddress }?.value, 250_000)
        XCTAssertEqual(
            transaction.vout.first { $0.scriptpubkeyAddress == sender.firstReceiveAddress }?.value,
            1_000_000 - 250_000 - Int64(quotedFee)
        )
        let remaining = try await esplora.utxos(address: sender.firstReceiveAddress)
        XCTAssertEqual(remaining.map(\.txid), [txid])
    }

    func testBitcoinRegtestSend_whenVetoArrivesAfterQuote_thenNothingIsBroadcast() async throws {
        let esplora = try LocalRegtestEsplora(baseURL: localEndpoint("FEARLESS_E2E_ESPLORA_URL"))
        let mnemonic = Self.bitcoinVetoedMnemonic
        let sender = try BitcoinKeyDerivation.deriveAccount(mnemonic: mnemonic, network: .testnet)
        let recipient = try BitcoinKeyDerivation.deriveAccount(mnemonic: Self.recipientMnemonic, network: .testnet)
        let fundingTxid = try await esplora.fund(address: sender.firstReceiveAddress, sats: 500_000)
        let service = makeBitcoinService(mnemonic: mnemonic, publicKey: sender.publicKey, esplora: esplora)
        let transfer = Self.bitcoinTransfer(sats: 100_000, recipient: recipient.firstReceiveAddress)
        _ = try await service.estimateFee(for: transfer)
        let mempoolBefore = try await esplora.mempool()

        // The emergency veto arrives through the real remote-config path after the review screen.
        try MultiChainFeaturePolicy.update(
            GithubJSONDecoder().decode(FeatureToggleConfig.self, from: Data(#"{"bitcoin_send_enabled":false}"#.utf8))
        )

        do {
            _ = try await service.submit(transfer: transfer)
            XCTFail("Expected the vetoed transfer to stop before broadcast")
        } catch TransferServiceError.bitcoinSendPaused {
            // Expected.
        }

        let mempoolAfter = try await esplora.mempool()
        XCTAssertEqual(Set(mempoolAfter), Set(mempoolBefore))
        let utxos = try await esplora.utxos(address: sender.firstReceiveAddress)
        XCTAssertEqual(utxos.map(\.txid), [fundingTxid])
    }

    func testSolanaLocalValidatorSend_whenEnabledByDefault_thenTransferConfirmsWithExactAmounts() async throws {
        let validator = try LocalSolanaValidator(rpcURL: localEndpoint("FEARLESS_E2E_SOLANA_RPC_URL"))
        let mnemonic = Self.solanaSenderMnemonic
        let sender = try SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic)
        let recipient = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.recipientMnemonic)
        try await validator.airdrop(to: sender.address, lamports: 2_000_000_000)
        let service = try makeSolanaService(mnemonic: mnemonic, publicKey: sender.publicKey, validator: validator)
        let transfer = Self.solanaTransfer(lamports: 10_000_000, recipient: recipient.address, rpcURL: validator.rpcURL)
        let senderBefore = try await validator.balance(of: sender.address)
        let recipientBefore = try await validator.balance(of: recipient.address)

        let quotedFee = try await service.estimateFee(for: transfer)
        let signature = try await service.submit(transfer: transfer)
        try await validator.waitUntilConfirmed(signature)

        let senderAfter = try await validator.balance(of: sender.address)
        let recipientAfter = try await validator.balance(of: recipient.address)
        XCTAssertEqual(recipientAfter - recipientBefore, 10_000_000)
        XCTAssertEqual(senderBefore - senderAfter, 10_000_000 + Int64(quotedFee))
    }

    func testSolanaLocalValidatorSend_whenVetoed_thenNoSignatureReachesTheValidator() async throws {
        let validator = try LocalSolanaValidator(rpcURL: localEndpoint("FEARLESS_E2E_SOLANA_RPC_URL"))
        let mnemonic = Self.solanaVetoedMnemonic
        let sender = try SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic)
        let recipient = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.recipientMnemonic)
        try await validator.airdrop(to: sender.address, lamports: 1_000_000_000)
        let service = try makeSolanaService(mnemonic: mnemonic, publicKey: sender.publicKey, validator: validator)
        let transfer = Self.solanaTransfer(lamports: 5_000_000, recipient: recipient.address, rpcURL: validator.rpcURL)
        _ = try await service.estimateFee(for: transfer)
        let signaturesBefore = try await validator.signatureCount(for: sender.address)
        let balanceBefore = try await validator.balance(of: sender.address)

        try MultiChainFeaturePolicy.update(
            GithubJSONDecoder().decode(FeatureToggleConfig.self, from: Data(#"{"solana_send_enabled":false}"#.utf8))
        )

        do {
            _ = try await service.submit(transfer: transfer)
            XCTFail("Expected the vetoed transfer to stop before signing")
        } catch TransferServiceError.solanaSendPaused {
            // Expected.
        }

        let signaturesAfter = try await validator.signatureCount(for: sender.address)
        let balanceAfter = try await validator.balance(of: sender.address)
        XCTAssertEqual(signaturesAfter, signaturesBefore)
        XCTAssertEqual(balanceAfter, balanceBefore)
    }

    // MARK: - Builders

    private func localEndpoint(_ name: String) throws -> URL {
        guard let value = ProcessInfo.processInfo.environment[name], let url = URL(string: value) else {
            throw XCTSkip("\(name) is not set; run scripts/test-local-chain-sends.sh to start the local chains")
        }
        guard url.scheme == "http", ["127.0.0.1", "localhost"].contains(url.host ?? "") else {
            XCTFail("\(name) must point at a local chain on 127.0.0.1, got \(value)")
            throw LocalChainError.notLocal(value)
        }
        return url
    }

    private func makeBitcoinService(
        mnemonic: String,
        publicKey: Data,
        esplora: LocalRegtestEsplora
    ) -> BitcoinTransferService {
        let wallet = AccountGenerator.generateMetaAccount(with: [
            ChainAccountModel(
                chainId: UniversalWalletRegistry.bitcoinTestnet.chainId,
                accountId: publicKey,
                publicKey: publicKey,
                cryptoType: CryptoType.ecdsa.rawValue,
                ethereumBased: false
            )
        ])
        return BitcoinTransferService(
            wallet: wallet,
            chain: Self.bitcoinChain,
            client: BitcoinIndexerClient(transport: esplora.transport),
            mnemonicProvider: LocalChainMnemonicProvider(mnemonic: mnemonic),
            sendGate: .production
        )
    }

    private func makeSolanaService(
        mnemonic: String,
        publicKey: Data,
        validator: LocalSolanaValidator
    ) throws -> SolanaTransferService {
        let wallet = AccountGenerator.generateMetaAccount(with: [
            ChainAccountModel(
                chainId: UniversalWalletRegistry.solanaMainnet.chainId,
                accountId: publicKey,
                publicKey: publicKey,
                cryptoType: CryptoType.ed25519.rawValue,
                ethereumBased: false
            )
        ])
        // Balances come from the app's own JSON-RPC reader over the validator.
        return try SolanaTransferService(
            wallet: wallet,
            chain: Self.solanaChain(rpcURL: validator.rpcURL),
            mnemonicProvider: LocalChainMnemonicProvider(mnemonic: mnemonic),
            sendGate: .production,
            pendingStore: SolanaPendingBroadcastStore(
                userDefaults: UserDefaults(suiteName: "SendLocalChainE2ETests.\(UUID().uuidString)")!,
                logger: nil
            ),
            providerRPCURL: nil,
            networkDefinition: try validator.capturedNetwork()
        )
    }

    private static let bitcoinSenderMnemonic =
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let bitcoinVetoedMnemonic =
        "legal winner thank year wave sausage worth useful legal winner thank yellow"
    private static let solanaSenderMnemonic =
        "letter advice cage absurd amount doctor acoustic avoid letter advice cage above"
    private static let solanaVetoedMnemonic =
        "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong"
    private static let recipientMnemonic =
        "void come effort suffer camp survey warrior heavy shoot primary clutch crush open amazing screen patrol group space point ten exist slush involve unfold"

    private static let btcAsset = AssetModel(
        id: "BTC",
        name: "Bitcoin",
        symbol: "BTC",
        precision: 8,
        isUtility: true,
        isNative: true
    )
    private static let solAsset = AssetModel(
        id: "SOL",
        name: "Solana",
        symbol: "SOL",
        precision: 9,
        isUtility: true,
        isNative: true
    )

    private static let bitcoinChain = ChainModel(
        rank: nil,
        disabled: false,
        chainId: UniversalWalletRegistry.bitcoinTestnet.chainId,
        parentId: nil,
        paraId: nil,
        name: "Bitcoin Testnet",
        assets: [btcAsset],
        xcm: nil,
        nodes: [],
        addressPrefix: 0,
        types: nil,
        icon: nil,
        options: [.testnet],
        externalApi: nil,
        selectedNode: nil,
        customNodes: nil,
        iosMinAppVersion: nil,
        identityChain: nil
    )

    private static func solanaChain(rpcURL: URL) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            parentId: nil,
            paraId: nil,
            name: "Solana",
            assets: [solAsset],
            xcm: nil,
            nodes: [ChainNodeModel(url: rpcURL, name: "solana-test-validator", apikey: nil)],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private static func bitcoinTransfer(sats: Int64, recipient: String) -> Transfer {
        Transfer(
            chainAsset: ChainAsset(chain: bitcoinChain, asset: btcAsset),
            amount: BigUInt(UInt64(sats)),
            receiver: recipient,
            tip: nil,
            appId: nil
        )
    }

    private static func solanaTransfer(lamports: Int64, recipient: String, rpcURL: URL) -> Transfer {
        Transfer(
            chainAsset: ChainAsset(chain: solanaChain(rpcURL: rpcURL), asset: solAsset),
            amount: BigUInt(UInt64(lamports)),
            receiver: recipient,
            tip: nil,
            appId: nil
        )
    }
}

// MARK: - Solana sends on a local validator (IOSUX-4)

/// Drives the real `SolanaTransferService` (recipient checks, rent rules, compute budget,
/// builder, signer, simulation, pending-broadcast record, failover RPC client and the app's
/// own JSON-RPC balance reader) against `solana-test-validator`, directly and through
/// `scripts/local-chains/solana_rpc_proxy.py`, which plays two RPC nodes and can fail the way
/// public nodes do. The SPL token is a genesis fixture (`solana_spl_fixture.py`) held by the
/// reference wallet. Every request stays on 127.0.0.1.
final class SolanaLocalChainE2ETests: XCTestCase {
    private var stores: [String] = []

    override func setUp() {
        super.setUp()
        MultiChainFeaturePolicy.liftRememberedVetoes()
    }

    override func tearDown() async throws {
        if let proxy = try? LocalSolanaProxy(baseURL: localEndpoint("FEARLESS_E2E_SOLANA_PROXY_URL")) {
            try? await proxy.reset()
        }
        stores.forEach { UserDefaults.standard.removePersistentDomain(forName: $0) }
        MultiChainFeaturePolicy.liftRememberedVetoes()
        try await super.tearDown()
    }

    func testSolSend_paysTheQuotedFeeWithItsPriorityFeeAndTheExactAmount() async throws {
        let validator = try LocalSolanaValidator(rpcURL: localEndpoint("FEARLESS_E2E_SOLANA_RPC_URL"))
        let context = try await makeContext(nodes: [validator.rpcURL], funding: 2_000_000_000, validator: validator)
        let recipient = try Self.freshAddress()
        let transfer = Self.transfer(lamports: 10_000_000, recipient: recipient, chain: context.chain)

        let quotedFee = try await context.service.estimateFee(for: transfer)
        let signature = try await context.service.submit(transfer: transfer)
        try await validator.waitUntilConfirmed(signature)

        // 5,000 lamports per signature plus ceil(2,000 units x 1,000 micro-lamports) = 2.
        XCTAssertEqual(quotedFee, BigUInt(5002))
        let senderAfter = try await validator.balance(of: context.address)
        let recipientAfter = try await validator.balance(of: recipient)
        XCTAssertEqual(recipientAfter, 10_000_000)
        XCTAssertEqual(senderAfter, 2_000_000_000 - 10_000_000 - 5002)
        // The balance the wallet shows comes from the same node, not from the SORA indexer.
        let shown = try await SolanaRpcBalanceSync(rpcClient: context.client).balances(
            wallet: context.address,
            network: try validator.capturedNetwork()
        )
        XCTAssertEqual(shown.nativeBalance.amount, String(senderAfter))
        XCTAssertNil(context.store.pending(for: context.scope))
    }

    func testRentRules_refuseBeforeSigningWithTheValidatorsOwnMinimum() async throws {
        let validator = try LocalSolanaValidator(rpcURL: localEndpoint("FEARLESS_E2E_SOLANA_RPC_URL"))
        let context = try await makeContext(nodes: [validator.rpcURL], funding: 1_000_000_000, validator: validator)
        let minimum = try await validator.rentExemptMinimum(dataLength: 0)

        await assertRefusal(.amountBelowNewAccountMinimum(minimumLamports: minimum)) {
            _ = try await context.service.submit(
                transfer: Self.transfer(lamports: minimum - 1, recipient: Self.freshAddress(), chain: context.chain)
            )
        }
        let fee: Int64 = 5002
        await assertRefusal(.remainderBelowAccountMinimum(minimumLamports: minimum)) {
            _ = try await context.service.submit(
                transfer: Self.transfer(lamports: 1_000_000_000 - fee - 1000, recipient: Self.freshAddress(), chain: context.chain)
            )
        }

        let signatures = try await validator.signatureCount(for: context.address)
        let balance = try await validator.balance(of: context.address)
        XCTAssertEqual(signatures, 1, "Only the airdrop")
        XCTAssertEqual(balance, 1_000_000_000)

        // "Max" leaves nothing, which the network accepts.
        let recipient = try Self.freshAddress()
        let signature = try await context.service.submit(
            transfer: Self.transfer(lamports: 1_000_000_000 - fee, recipient: recipient, chain: context.chain)
        )
        try await validator.waitUntilConfirmed(signature)
        let emptied = try await validator.balance(of: context.address)
        let received = try await validator.balance(of: recipient)
        XCTAssertEqual(emptied, 0)
        XCTAssertEqual(received, 1_000_000_000 - fee)
    }

    func testSplSend_opensTheRecipientsTokenAccountOnceAndRefusesTokenAccountRecipients() async throws {
        let validator = try LocalSolanaValidator(rpcURL: localEndpoint("FEARLESS_E2E_SOLANA_RPC_URL"))
        let mint = try localValue("FEARLESS_E2E_SOLANA_SPL_MINT")
        let source = try localValue("FEARLESS_E2E_SOLANA_SPL_SOURCE")
        let token = AssetModel(id: mint, name: "Local token", symbol: "LTK", precision: 6, currencyId: mint, isUtility: false, isNative: false)
        let context = try await makeContext(
            mnemonic: Self.splHolderMnemonic,
            nodes: [validator.rpcURL],
            funding: 1_000_000_000,
            validator: validator,
            extraAssets: [token]
        )
        XCTAssertEqual(context.address, "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk", "The fixture's token holder")
        let recipient = try Self.freshAddress()
        let recipientTokenAccount = try SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
            walletAddress: recipient,
            mintAddress: mint,
            tokenProgram: .splToken
        )
        let sourceBefore = try await validator.tokenBalance(of: source)
        let solBefore = try await validator.balance(of: context.address)
        let rent = try await validator.rentExemptMinimum(dataLength: 165)

        // The app sees the holding through its own JSON-RPC balance reader.
        let shown = try await SolanaRpcBalanceSync(rpcClient: context.client).balances(
            wallet: context.address,
            network: try validator.capturedNetwork()
        )
        XCTAssertEqual(shown.tokenBalances.map(\.tokenAccountId), [source])

        let first = Self.transfer(amount: 1_250_000, asset: token, recipient: recipient, chain: context.chain)
        let firstFee = try await context.service.estimateFee(for: first)
        let firstSignature = try await context.service.submit(transfer: first)
        try await validator.waitUntilConfirmed(firstSignature)

        // Network fee, ceil(100,000 units x 1,000 micro-lamports) = 100, and the new account's rent.
        XCTAssertEqual(firstFee, BigUInt(UInt64(5000 + 100 + rent)))
        let recipientAfterFirst = try await validator.tokenBalance(of: recipientTokenAccount)
        let solAfterFirst = try await validator.balance(of: context.address)
        XCTAssertEqual(recipientAfterFirst, 1_250_000)
        XCTAssertEqual(solAfterFirst, solBefore - Int64(firstFee))

        let second = Self.transfer(amount: 250_000, asset: token, recipient: recipient, chain: context.chain)
        let secondFee = try await context.service.estimateFee(for: second)
        let secondSignature = try await context.service.submit(transfer: second)
        try await validator.waitUntilConfirmed(secondSignature)

        XCTAssertEqual(secondFee, BigUInt(5000 + 40), "The account exists now: no rent, a smaller budget")
        let recipientAfterSecond = try await validator.tokenBalance(of: recipientTokenAccount)
        let sourceAfter = try await validator.tokenBalance(of: source)
        let solAfterSecond = try await validator.balance(of: context.address)
        XCTAssertEqual(recipientAfterSecond, 1_500_000)
        XCTAssertEqual(sourceAfter, sourceBefore - 1_500_000)
        XCTAssertEqual(solAfterSecond, solAfterFirst - 5040)

        // A token account is not a wallet: tokens or SOL sent there are refused before signing.
        let signaturesBefore = try await validator.signatureCount(for: context.address)
        await assertRefusal(.recipientNotWallet) {
            _ = try await context.service.submit(
                transfer: Self.transfer(amount: 1, asset: token, recipient: recipientTokenAccount, chain: context.chain)
            )
        }
        await assertRefusal(.recipientIsTokenAccount) {
            _ = try await context.service.submit(
                transfer: Self.transfer(lamports: 10_000_000, recipient: recipientTokenAccount, chain: context.chain)
            )
        }
        await assertRefusal(.recipientIsTokenAccount) {
            _ = try await context.service.submit(
                transfer: Self.transfer(lamports: 10_000_000, recipient: source, chain: context.chain)
            )
        }
        let signaturesAfter = try await validator.signatureCount(for: context.address)
        let recipientUnchanged = try await validator.tokenBalance(of: recipientTokenAccount)
        XCTAssertEqual(signaturesAfter, signaturesBefore)
        XCTAssertEqual(recipientUnchanged, 1_500_000)
    }

    /// A node forwards the transaction but its reply is lost, and the second node cannot say
    /// either. The signature status settles it: one payment, reported as sent.
    func testLostBroadcastReply_thenTheSignatureStatusSettlesItWithOnePayment() async throws {
        let validator = try LocalSolanaValidator(rpcURL: localEndpoint("FEARLESS_E2E_SOLANA_RPC_URL"))
        let proxy = try LocalSolanaProxy(baseURL: localEndpoint("FEARLESS_E2E_SOLANA_PROXY_URL"))
        let context = try await makeContext(nodes: proxy.nodes, funding: 1_000_000_000, validator: validator)
        let recipient = try Self.freshAddress()
        let transfer = Self.transfer(lamports: 20_000_000, recipient: recipient, chain: context.chain)
        _ = try await context.service.estimateFee(for: transfer)
        try await proxy.fault(service: "a-primary", method: "sendTransaction", mode: "accept_then_drop")
        try await proxy.fault(service: "b-secondary", method: "sendTransaction", mode: "accept_then_502")

        let signature = try await context.service.submit(transfer: transfer)
        try await validator.waitUntilConfirmed(signature)

        let received = try await validator.balance(of: recipient)
        let remaining = try await validator.balance(of: context.address)
        let signatures = try await validator.signatureCount(for: context.address)
        XCTAssertEqual(received, 20_000_000)
        XCTAssertEqual(remaining, 1_000_000_000 - 20_000_000 - 5002)
        XCTAssertEqual(signatures, 2, "The airdrop and one transfer")
        XCTAssertNil(context.store.pending(for: context.scope))
    }

    /// No node took the transaction and nobody can tell. The wallet says the status is
    /// unknown, refuses to sign another transfer, and Retry sends the very same transaction:
    /// it lands once.
    func testUnreachableBroadcast_thenUnknownOutcome_nothingNewIsSigned_andRetryLandsOnce() async throws {
        let validator = try LocalSolanaValidator(rpcURL: localEndpoint("FEARLESS_E2E_SOLANA_RPC_URL"))
        let proxy = try LocalSolanaProxy(baseURL: localEndpoint("FEARLESS_E2E_SOLANA_PROXY_URL"))
        let context = try await makeContext(nodes: proxy.nodes, funding: 1_000_000_000, validator: validator)
        let recipient = try Self.freshAddress()
        let transfer = Self.transfer(lamports: 30_000_000, recipient: recipient, chain: context.chain)
        _ = try await context.service.estimateFee(for: transfer)
        try await proxy.fault(service: "*", method: "sendTransaction", mode: "drop", count: 2)

        let signature = try await assertUnknownOutcome { try await context.service.submit(transfer: transfer) }
        XCTAssertEqual(context.store.pending(for: context.scope)?.signature, signature)
        let untouched = try await validator.balance(of: context.address)
        XCTAssertEqual(untouched, 1_000_000_000, "Nothing reached the validator")

        do {
            _ = try await context.service.submit(transfer: transfer)
            XCTFail("A second transfer must wait for the first")
        } catch let TransferServiceError.solanaPriorTransferUnresolved(pending) {
            XCTAssertEqual(pending, signature)
        }
        let sendsBeforeRetry = try await proxy.requests().values.flatMap { $0 }.filter { $0 == "sendTransaction" }.count
        XCTAssertEqual(sendsBeforeRetry, 2, "Nothing new was signed or sent")

        let retried = try await context.service.retryUnresolvedTransfer(hash: signature)
        XCTAssertEqual(retried, signature, "Retry sends the same transaction")
        try await validator.waitUntilConfirmed(signature)

        let received = try await validator.balance(of: recipient)
        let signatures = try await validator.signatureCount(for: context.address)
        XCTAssertEqual(received, 30_000_000)
        XCTAssertEqual(signatures, 2, "The airdrop and one transfer")
        XCTAssertNil(context.store.pending(for: context.scope))
    }

    /// The same, but the user waits instead of retrying: once the blockhash has expired the
    /// first transfer can never land, so the next one goes ahead and only it is paid.
    func testUnreachableBroadcast_whenTheBlockhashExpires_thenTheNextTransferIsTheOnlyPayment() async throws {
        let validator = try LocalSolanaValidator(rpcURL: localEndpoint("FEARLESS_E2E_SOLANA_RPC_URL"))
        let proxy = try LocalSolanaProxy(baseURL: localEndpoint("FEARLESS_E2E_SOLANA_PROXY_URL"))
        let context = try await makeContext(nodes: proxy.nodes, funding: 1_000_000_000, validator: validator)
        let recipient = try Self.freshAddress()
        let transfer = Self.transfer(lamports: 40_000_000, recipient: recipient, chain: context.chain)
        _ = try await context.service.estimateFee(for: transfer)
        try await proxy.fault(service: "*", method: "sendTransaction", mode: "drop", count: 2)
        let first = try await assertUnknownOutcome { try await context.service.submit(transfer: transfer) }

        var second: String?
        var unverified: [String] = []
        // On a busy machine the validator can take several minutes to finalize past the first
        // transfer's last valid block height. The loop ends as soon as the next transfer goes.
        let deadline = Date().addingTimeInterval(600)
        while second == nil, Date() < deadline {
            do {
                second = try await context.service.submit(transfer: transfer)
            } catch TransferServiceError.solanaPriorTransferUnresolved {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch let TransferServiceError.solanaPriorTransferUnverified(signature) {
                // Both proxy nodes are one host, 127.0.0.1: one witness cannot say nothing left
                // the wallet. The record is released and the user confirms again.
                unverified.append(signature)
            }
        }
        let paid = try XCTUnwrap(second, "The first transfer never expired")
        XCTAssertEqual(unverified, [first], "Unverified once, then confirming again sends")
        XCTAssertNotEqual(paid, first)
        try await validator.waitUntilConfirmed(paid)

        let received = try await validator.balance(of: recipient)
        let firstStatus = try await validator.signatureStatus(first)
        XCTAssertEqual(received, 40_000_000, "Paid exactly once")
        XCTAssertNil(firstStatus, "The expired transaction never landed")
    }

    /// solana-rpc.publicnode.com refuses token-account lookups ("Request blocked"): the
    /// wallet's balances come from the next node.
    func testNodeThatBlocksTokenLookups_thenBalancesComeFromTheNextNode() async throws {
        let validator = try LocalSolanaValidator(rpcURL: localEndpoint("FEARLESS_E2E_SOLANA_RPC_URL"))
        let proxy = try LocalSolanaProxy(baseURL: localEndpoint("FEARLESS_E2E_SOLANA_PROXY_URL"))
        let context = try await makeContext(
            mnemonic: Self.splHolderMnemonic,
            nodes: proxy.nodes,
            funding: 10_000_000,
            validator: validator
        )
        let source = try localValue("FEARLESS_E2E_SOLANA_SPL_SOURCE")
        try await proxy.fault(service: "a-primary", method: "getTokenAccountsByOwner", mode: "rpc_blocked", count: 100)

        let shown = try await SolanaRpcBalanceSync(rpcClient: context.client).balances(
            wallet: context.address,
            network: try validator.capturedNetwork()
        )

        XCTAssertTrue(shown.tokenBalances.contains { $0.tokenAccountId == source })
        let requests = try await proxy.requests()
        XCTAssertEqual(requests["a-primary"]?.filter { $0 == "getTokenAccountsByOwner" }.count, 1, "Backed off after it said no")
        XCTAssertEqual(requests["b-secondary"]?.filter { $0 == "getTokenAccountsByOwner" }.count, 2)
    }

    /// Every node refuses getTokenAccountsByOwner, as publicnode does: the portfolio still shows
    /// the validator's SOL balance and says the token accounts were not read; a send's strict
    /// read fails instead of seeing no tokens. Once a node answers, the token is back.
    func testEveryNodeBlocksTokenLookups_thenThePortfolioStillShowsSolAndKeepsTokensUnread() async throws {
        let validator = try LocalSolanaValidator(rpcURL: localEndpoint("FEARLESS_E2E_SOLANA_RPC_URL"))
        let proxy = try LocalSolanaProxy(baseURL: localEndpoint("FEARLESS_E2E_SOLANA_PROXY_URL"))
        let context = try await makeContext(
            mnemonic: Self.splHolderMnemonic,
            nodes: proxy.nodes,
            funding: 10_000_000,
            validator: validator
        )
        let source = try localValue("FEARLESS_E2E_SOLANA_SPL_SOURCE")
        for service in ["a-primary", "b-secondary"] {
            try await proxy.fault(service: service, method: "getTokenAccountsByOwner", mode: "rpc_blocked", count: 100)
        }
        let network = try validator.capturedNetwork()
        let sync = SolanaRpcBalanceSync(rpcClient: context.client)

        let shown = try await sync.portfolioBalances(wallet: context.address, network: network, rpcURL: nil)
        let onChain = try await validator.balance(of: context.address)

        XCTAssertEqual(shown.nativeBalance.amount, String(onChain))
        XCTAssertTrue(shown.tokenBalancesUnavailable)
        XCTAssertTrue(shown.tokenBalances.isEmpty)
        do {
            _ = try await sync.balances(wallet: context.address, network: network)
            XCTFail("A send must not mistake unread token accounts for none")
        } catch {}

        try await proxy.reset()
        let recovered = try await SolanaRpcBalanceSync(rpcClient: context.client).portfolioBalances(
            wallet: context.address,
            network: network,
            rpcURL: nil
        )
        XCTAssertFalse(recovered.tokenBalancesUnavailable)
        XCTAssertTrue(recovered.tokenBalances.contains { $0.tokenAccountId == source })
    }

    /// The first node rate limits everything: one request finds out, then reads and the
    /// broadcast go to the second node while the first backs off.
    func testRateLimitingFirstNode_thenReadsAndTheBroadcastUseTheSecond() async throws {
        let validator = try LocalSolanaValidator(rpcURL: localEndpoint("FEARLESS_E2E_SOLANA_RPC_URL"))
        let proxy = try LocalSolanaProxy(baseURL: localEndpoint("FEARLESS_E2E_SOLANA_PROXY_URL"))
        let context = try await makeContext(nodes: proxy.nodes, funding: 1_000_000_000, validator: validator)
        try await proxy.fault(service: "a-primary", method: "*", mode: "429", count: 1000)
        let recipient = try Self.freshAddress()
        let transfer = Self.transfer(lamports: 50_000_000, recipient: recipient, chain: context.chain)

        _ = try await context.service.estimateFee(for: transfer)
        let signature = try await context.service.submit(transfer: transfer)
        try await validator.waitUntilConfirmed(signature)
        let shown = try await SolanaRpcBalanceSync(rpcClient: context.client).balances(
            wallet: context.address,
            network: try validator.capturedNetwork()
        )

        let received = try await validator.balance(of: recipient)
        XCTAssertEqual(received, 50_000_000)
        XCTAssertEqual(shown.nativeBalance.amount, String(1_000_000_000 - 50_000_000 - 5002))
        let requests = try await proxy.requests()
        // Status lookups ask every node, but every primary attempt must stop at its failed
        // genesis handshake. No business or status payload may reach this unverified node.
        let primaryRequests = try XCTUnwrap(requests["a-primary"])
        XCTAssertFalse(primaryRequests.isEmpty)
        XCTAssertTrue(primaryRequests.allSatisfy { $0 == "getGenesisHash" }, "Unexpected primary payload: \(primaryRequests)")
        XCTAssertTrue(requests["b-secondary"]?.contains("sendTransaction") == true)
    }

    // MARK: - The app's Send and Confirm screens

    /// The app's own Send and Confirm screens, used the way a person uses them. The recipient is
    /// pasted into the address field and the amount typed into the amount field (the calls UIKit
    /// makes for a paste and for each keystroke), Continue opens Confirm, which shows the quoted
    /// network fee, and Confirm sends to the local validator. The balances move exactly once.
    @MainActor
    func testSendAndConfirmScreens_pastedRecipientAndTypedAmount_payOnceOnTheValidator() async throws {
        let validator = try LocalSolanaValidator(rpcURL: localEndpoint("FEARLESS_E2E_SOLANA_RPC_URL"))
        // The screens read amounts in the selected language; compare them in English.
        let language = LocalizationManager.shared.selectedLocalization
        LocalizationManager.shared.selectedLocalization = "en"
        defer { LocalizationManager.shared.selectedLocalization = language }
        let context = try await makeContext(nodes: [validator.rpcURL], funding: 1_000_000_000, validator: validator)
        let recipient = try Self.freshAddress()
        let lamports: Int64 = 40_000_000
        let chainAsset = ChainAsset(chain: context.chain, asset: Self.solAsset)
        let quotedFee = try await context.service.estimateFee(
            for: Self.transfer(lamports: lamports, recipient: recipient, chain: context.chain)
        )
        let senderBefore = try await validator.balance(of: context.address)
        let signaturesBefore = try await validator.signatureCount(for: context.address)

        let screens = LocalSendScreens(
            wallet: context.wallet,
            chainAsset: chainAsset,
            service: context.service,
            balances: LocalValidatorBalances(validator: validator, address: context.address)
        )
        let navigation = UINavigationController(rootViewController: screens.send)
        let window = Self.makeWindow(root: navigation)
        defer { window.isHidden = true }
        let send = screens.send
        let diagnostics = {
            "Sheets: \(screens.router.sheets + screens.wireframe.sheets); " +
                "app state \(UIApplication.shared.applicationState.rawValue), " +
                "scene \(String(describing: window.windowScene?.activationState.rawValue)), " +
                "form open \(send.allowsSendFormContinuation), " +
                "top \(String(describing: navigation.topViewController)), " +
                "presented \(Self.describePresented(navigation))"
        }

        try await Self.waitUntil("Send reads the balance", diagnostics: diagnostics) {
            screens.balances.reads > 0
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        let addressField = send.rootView.searchView.textField
        _ = send.textField(addressField, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: recipient)
        let amountField = send.rootView.amountView.textField
        for character in "0.04" {
            let end = (amountField.text ?? "").count
            _ = send.textField(amountField, shouldChangeCharactersIn: NSRange(location: end, length: 0), replacementString: String(character))
        }
        try await Self.waitUntil("Send quotes the fee and offers Continue", diagnostics: diagnostics) {
            !(send.rootView.feeView.tokenLabel.text ?? "").isEmpty && send.rootView.actionButton.isEnabled &&
                send.allowsSendFormContinuation
        }
        XCTAssertEqual(addressField.text, recipient)
        send.rootView.actionButton.sendActions(for: .touchUpInside)

        try await Self.waitUntil("Confirm opens", diagnostics: diagnostics) {
            navigation.topViewController === screens.router.confirm && screens.router.confirm?.isViewLoaded == true
        }
        let confirm = try XCTUnwrap(screens.router.confirm)
        let confirmDiagnostics = {
            diagnostics() + "; confirm fee \(String(describing: confirm.rootView.feeView.valueTop.text)), " +
                "amount \(String(describing: confirm.rootView.amountView.valueTop.text)), " +
                "button enabled \(confirm.rootView.confirmButton.isEnabled), " +
                "interactive \(confirm.rootView.confirmButton.isUserInteractionEnabled)"
        }
        try await Self.waitUntil("Confirm shows the fee and enables Confirm", diagnostics: confirmDiagnostics) {
            !(confirm.rootView.feeView.valueTop.text ?? "").isEmpty && confirm.rootView.confirmButton.isEnabled &&
                confirm.rootView.confirmButton.isUserInteractionEnabled
        }
        let shownFee = try XCTUnwrap(Self.shownAmount(confirm.rootView.feeView.valueTop.text), confirmDiagnostics())
        XCTAssertEqual(
            shownFee.value,
            Self.rounded(quotedFee, fractionDigits: shownFee.fractionDigits),
            "Confirm shows the quoted fee as the app rounds it: \(confirmDiagnostics())"
        )
        XCTAssertTrue((confirm.rootView.amountView.valueTop.text ?? "").contains("0.04"), confirmDiagnostics())
        confirm.rootView.confirmButton.sendActions(for: .touchUpInside)

        try await Self.waitUntil("the transfer is reported sent", timeout: 120, diagnostics: confirmDiagnostics) {
            screens.wireframe.completedHash != nil
        }
        let signature = try XCTUnwrap(screens.wireframe.completedHash)
        try await validator.waitUntilConfirmed(signature)
        let received = try await validator.balance(of: recipient)
        let senderAfter = try await validator.balance(of: context.address)
        let signaturesAfter = try await validator.signatureCount(for: context.address)
        XCTAssertEqual(received, lamports, "The recipient got the typed amount")
        XCTAssertEqual(senderBefore - senderAfter, lamports + Int64(quotedFee), "The sender paid the amount and the quoted fee")
        XCTAssertEqual(signaturesAfter - signaturesBefore, 1, "One payment")
    }

    /// The amount a screen shows ("0.000005 SOL") and how many decimals it shows.
    private static func shownAmount(_ text: String?) -> (value: Decimal, fractionDigits: Int)? {
        guard let text, let range = text.range(of: #"[0-9]+(\.[0-9]+)?"#, options: .regularExpression),
              let value = Decimal(string: String(text[range]), locale: Locale(identifier: "en_US")) else {
            return nil
        }
        let fraction = text[range].split(separator: ".").dropFirst().first?.count ?? 0
        return (value, fraction)
    }

    /// Lamports in SOL, rounded to the decimals a screen shows.
    private static func rounded(_ lamports: BigUInt, fractionDigits: Int) -> Decimal {
        var value = Decimal.fromSubstrateAmount(lamports, precision: 9) ?? 0
        var result = Decimal()
        NSDecimalRound(&result, &value, fractionDigits, .plain)
        return result
    }

    /// What is shown over the screens, with every text in it, for a failure message.
    @MainActor
    private static func describePresented(_ root: UIViewController) -> String {
        var controller = root.presentedViewController
        var parts: [String] = []
        while let shown = controller {
            var texts: [String] = []
            func collect(_ view: UIView) {
                if let label = view as? UILabel, let text = label.text, !text.isEmpty { texts.append(text) }
                view.subviews.forEach(collect)
            }
            if let alert = shown as? UIAlertController {
                texts.append(contentsOf: [alert.title, alert.message].compactMap { $0 })
            }
            shown.viewIfLoaded.map(collect)
            parts.append("\(type(of: shown)) \(texts)")
            controller = shown.presentedViewController
        }
        return parts.isEmpty ? "nothing" : parts.joined(separator: " > ")
    }

    @MainActor
    private static func makeWindow(root: UIViewController) -> UIWindow {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: UIScreen.main.bounds)
        window.frame = UIScreen.main.bounds
        window.rootViewController = root
        window.makeKeyAndVisible()
        return window
    }

    @MainActor
    private static func waitUntil(
        _ what: String,
        timeout: TimeInterval = 60,
        file: StaticString = #filePath,
        line: UInt = #line,
        diagnostics: () -> String = { "" },
        _ condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Timed out waiting until \(what). \(diagnostics())", file: file, line: line)
                throw LocalChainError.rpc("timed out waiting until \(what)")
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    // MARK: - Builders

    private struct Context {
        let service: SolanaTransferService
        let client: SolanaFailoverRpcClient
        let store: SolanaPendingBroadcastStore
        let scope: SolanaPendingBroadcastScope
        let address: String
        let chain: ChainModel
        let wallet: MetaAccountModel
    }

    private func makeContext(
        mnemonic: String? = nil,
        nodes: [URL],
        funding: Int64,
        validator: LocalSolanaValidator,
        extraAssets: [AssetModel] = []
    ) async throws -> Context {
        let mnemonic = try mnemonic ?? IRMnemonicCreator().randomMnemonic(.entropy128).toString()
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic)
        let wallet = AccountGenerator.generateMetaAccount(with: [
            ChainAccountModel(
                chainId: UniversalWalletRegistry.solanaMainnet.chainId,
                accountId: account.publicKey,
                publicKey: account.publicKey,
                cryptoType: CryptoType.ed25519.rawValue,
                ethereumBased: false
            )
        ])
        let chain = Self.chain(nodes: nodes, extraAssets: extraAssets)
        let definition = try validator.capturedNetwork()
        let endpoints = SolanaRpcEndpoints.endpoints(for: chain, network: definition, providerURL: nil)
        XCTAssertTrue(endpoints.allSatisfy { URL(string: $0)?.host == "127.0.0.1" }, "Private fixture cannot use public endpoints")
        let client = try SolanaFailoverRpcClient(endpoints: endpoints, health: UniversalWalletEndpointHealth(),
                                                expectedGenesisHash: definition.genesisHash)
        let suite = "SolanaLocalChainE2ETests.\(UUID().uuidString)"
        stores.append(suite)
        let store = try SolanaPendingBroadcastStore(userDefaults: XCTUnwrap(UserDefaults(suiteName: suite)), logger: nil)
        let service = try SolanaTransferService(
            wallet: wallet,
            chain: chain,
            rpcClient: client,
            mnemonicProvider: LocalChainMnemonicProvider(mnemonic: mnemonic),
            sendGate: .production,
            pendingStore: store,
            confirmationPolicy: SolanaConfirmationPolicy(timeout: 3, pollInterval: 0.25),
            providerRPCURL: nil,
            networkDefinition: definition
        )
        try await validator.airdrop(to: account.address, lamports: funding)

        return Context(
            service: service,
            client: client,
            store: store,
            scope: SolanaPendingBroadcastScope(walletId: wallet.metaId, chainId: chain.chainId),
            address: account.address,
            chain: chain,
            wallet: wallet
        )
    }

    private func assertUnknownOutcome(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ block: () async throws -> String
    ) async throws -> String {
        do {
            _ = try await block()
        } catch let TransferServiceError.solanaBroadcastOutcomeUnknown(signature) {
            return signature
        }
        XCTFail("Expected an unknown outcome", file: file, line: line)
        throw LocalChainError.rpc("no unknown outcome")
    }

    private func assertRefusal(
        _ expected: SolanaTransferRefusal,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? SolanaTransferRefusal, expected, "\(error)", file: file, line: line)
        }
    }

    private func localEndpoint(_ name: String) throws -> URL {
        let value = try localValue(name)
        guard let url = URL(string: value), url.scheme == "http", ["127.0.0.1", "localhost"].contains(url.host ?? "") else {
            XCTFail("\(name) must point at a local chain on 127.0.0.1, got \(value)")
            throw LocalChainError.notLocal(value)
        }
        return url
    }

    private func localValue(_ name: String) throws -> String {
        guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
            throw XCTSkip("\(name) is not set; run scripts/test-local-chain-sends.sh to start the local chains")
        }
        return value
    }

    private static func freshAddress() throws -> String {
        try SolanaKeyDerivation.deriveAccount(mnemonic: IRMnemonicCreator().randomMnemonic(.entropy128).toString()).address
    }

    /// The fixture's token holder: the reference phrase whose Solana address is HAgk14...
    private static let splHolderMnemonic =
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    private static let solAsset = AssetModel(id: "SOL", name: "Solana", symbol: "SOL", precision: 9, isUtility: true, isNative: true)

    private static func chain(nodes: [URL], extraAssets: [AssetModel]) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            parentId: nil,
            paraId: nil,
            name: "Solana",
            assets: Set([solAsset] + extraAssets),
            xcm: nil,
            nodes: Set(nodes.map { ChainNodeModel(url: $0, name: $0.path.isEmpty ? "validator" : $0.lastPathComponent, apikey: nil) }),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private static func transfer(lamports: Int64, recipient: String, chain: ChainModel) -> Transfer {
        Transfer(
            chainAsset: ChainAsset(chain: chain, asset: solAsset),
            amount: BigUInt(UInt64(lamports)),
            receiver: recipient,
            tip: nil,
            appId: nil
        )
    }

    private static func transfer(amount: Int64, asset: AssetModel, recipient: String, chain: ChainModel) -> Transfer {
        Transfer(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            amount: BigUInt(UInt64(amount)),
            receiver: recipient,
            tip: nil,
            appId: nil
        )
    }
}

// MARK: - Bitcoin send correctness on a local regtest chain (IOSUX-3)

/// Drives the real `BitcoinTransferService` (planner, builder, signer, pending-broadcast record,
/// failover indexer client) against `bitcoind -regtest` behind the Esplora shim, which plays
/// both of the app's production services (mempool.space and blockstream.info) and can fail
/// the way public indexers do. Every test uses a fresh random wallet; nothing leaves 127.0.0.1.
final class BitcoinLocalChainE2ETests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        MultiChainFeaturePolicy.liftRememberedVetoes()
        suiteName = "BitcoinLocalChainE2ETests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() async throws {
        if let esplora = try? LocalRegtestEsplora(baseURL: localEndpoint()) {
            try? await esplora.reset()
        }
        defaults?.removePersistentDomain(forName: suiteName)
        MultiChainFeaturePolicy.liftRememberedVetoes()
        try await super.tearDown()
    }

    /// The audit's double payment: the node takes the transaction, the reply is lost and the
    /// indexers cannot be asked. The wallet must neither call it failed nor build a second
    /// payment from the other coin, and must report the first payment once it can see it.
    func testAmbiguousBroadcast_whenTheNodeTookItAndTheReplyWasLost_thenNoSecondPaymentIsEverBuilt() async throws {
        let esplora = try LocalRegtestEsplora(baseURL: localEndpoint())
        let context = try await makeContext(esplora: esplora)
        _ = try await esplora.fund(address: context.address, sats: 600_000)
        let otherCoin = try await esplora.fund(address: context.address, sats: 500_000)
        let recipient = try await esplora.newAddress(type: "bech32")
        let transfer = Self.transfer(sats: 250_000, recipient: recipient)
        try await esplora.fault(service: "mempool", route: "broadcast", mode: "accept_then_drop")
        try await esplora.fault(service: "blockstream", route: "broadcast", mode: "accept_then_502")
        try await esplora.fault(service: "*", route: "lookup", mode: "drop", count: 1000)

        _ = try await context.service.estimateFee(for: transfer)
        let txid = try await assertOutcomeUnknown { try await context.service.submit(transfer: transfer) }

        let mempool = try await esplora.mempool()
        XCTAssertEqual(mempool, [txid], "The first payment is on the network")
        XCTAssertEqual(context.store.pending(for: context.scope)?.txid, txid)

        // The user tries again. The indexer no longer lists the spent coin, so a fresh plan
        // would take the other one: refused before anything is planned or signed.
        _ = try await context.service.estimateFee(for: transfer)
        await assertTransferError(.bitcoinPriorTransferUnresolved(txid: txid)) {
            _ = try await context.service.submit(transfer: transfer)
        }
        let mempoolAfterRetry = try await esplora.mempool()
        XCTAssertEqual(mempoolAfterRetry, [txid])

        // The indexers answer again: the wallet learns the payment went out and says so.
        try await esplora.reset()
        await assertTransferError(.bitcoinPriorTransferConfirmed(txid: txid)) {
            _ = try await context.service.submit(transfer: transfer)
        }
        XCTAssertNil(context.store.pending(for: context.scope))

        _ = try await esplora.mine(blocks: 1)
        let transaction = try await esplora.transaction(txid)
        XCTAssertTrue(transaction.status.confirmed)
        XCTAssertEqual(transaction.vout.filter { $0.scriptpubkeyAddress == recipient }.map(\.value), [250_000])
        let utxos = try await esplora.utxos(address: context.address)
        XCTAssertTrue(utxos.contains { $0.txid == otherCoin }, "The other coin was never spent")
        let finalMempool = try await esplora.mempool()
        XCTAssertTrue(finalMempool.isEmpty)
    }

    /// The broadcast never reached the node. electrs answers `/tx/:txid/status` for such an
    /// unknown transaction with `{"confirmed":false}`, so a wallet reading that route would
    /// call it sent; this one asks `/tx/:txid`, keeps the transfer unresolved and, on Retry,
    /// sends the very same signed bytes once.
    func testAmbiguousBroadcast_whenNothingReachedTheNode_thenRetrySendsTheSameTransactionOnce() async throws {
        let esplora = try LocalRegtestEsplora(baseURL: localEndpoint())
        let context = try await makeContext(esplora: esplora)
        _ = try await esplora.fund(address: context.address, sats: 400_000)
        let recipient = try await esplora.newAddress(type: "bech32")
        let transfer = Self.transfer(sats: 120_000, recipient: recipient)
        try await esplora.fault(service: "*", route: "broadcast", mode: "drop", count: 2)

        let fee = try await context.service.estimateFee(for: transfer)
        let txid = try await assertOutcomeUnknown { try await context.service.submit(transfer: transfer) }

        let mempool = try await esplora.mempool()
        XCTAssertTrue(mempool.isEmpty, "Nothing reached the node")
        let isKnown = await esplora.isKnown(txid)
        XCTAssertFalse(isKnown)
        let record = try XCTUnwrap(context.store.pending(for: context.scope))
        XCTAssertEqual(record.txid, txid)

        let retriedTxid = try await context.service.retryUnresolvedTransfer(hash: txid)

        XCTAssertEqual(retriedTxid, txid)
        let mempoolAfterRetry = try await esplora.mempool()
        XCTAssertEqual(mempoolAfterRetry, [txid])
        XCTAssertNil(context.store.pending(for: context.scope))
        _ = try await esplora.mine(blocks: 1)
        let transaction = try await esplora.transaction(txid)
        XCTAssertTrue(transaction.status.confirmed)
        XCTAssertEqual(transaction.fee, Int64(fee))
        XCTAssertEqual(transaction.vout.filter { $0.scriptpubkeyAddress == recipient }.map(\.value), [120_000])
    }

    /// The user chose to replace an unresolved transfer. The replacement spends the earlier
    /// transfer's coin, so the network can accept at most one of them.
    func testReplacement_whenTheEarlierTransferNeverLeft_thenOnlyOneOfTheTwoCanConfirm() async throws {
        let esplora = try LocalRegtestEsplora(baseURL: localEndpoint())
        let context = try await makeContext(esplora: esplora)
        let stuckCoin = try await esplora.fund(address: context.address, sats: 300_000)
        let recipient = try await esplora.newAddress(type: "bech32")
        try await esplora.fault(service: "*", route: "broadcast", mode: "drop", count: 2)
        let first = Self.transfer(sats: 100_000, recipient: recipient)
        _ = try await context.service.estimateFee(for: first)
        let firstTxid = try await assertOutcomeUnknown { try await context.service.submit(transfer: first) }
        let firstHex = try XCTUnwrap(context.store.pending(for: context.scope)?.txHex)
        // A larger coin arrives; largest-first selection alone would now ignore the stuck coin.
        _ = try await esplora.fund(address: context.address, sats: 900_000)

        let allowed = await context.service.allowReplacingUnresolvedTransfer(hash: firstTxid)
        XCTAssertTrue(allowed)
        let replacement = Self.transfer(sats: 150_000, recipient: recipient)
        let fee = try await context.service.estimateFee(for: replacement)
        let replacementTxid = try await context.service.submit(transfer: replacement)

        let transaction = try await esplora.transaction(replacementTxid)
        XCTAssertTrue(transaction.vin.contains { $0.txid == stuckCoin }, "The replacement spends the earlier coin")
        XCTAssertEqual(transaction.fee, Int64(fee))
        do {
            _ = try await esplora.broadcastRaw(firstHex)
            XCTFail("The earlier transaction must conflict with the replacement")
        } catch {
            // Expected: the node refuses the conflicting earlier transaction.
        }
        _ = try await esplora.mine(blocks: 1)
        let confirmed = try await esplora.transaction(replacementTxid)
        XCTAssertTrue(confirmed.status.confirmed)
        let firstKnown = await esplora.isKnown(firstTxid)
        XCTAssertFalse(firstKnown, "The earlier transfer can never confirm")
        XCTAssertNil(context.store.pending(for: context.scope))
    }

    /// mempool.space rate limits the app. Reads and the broadcast move to blockstream.info, and
    /// the rate-limited service is not asked again for reads while its Retry-After lasts.
    func testRateLimitedPrimary_thenTheTransferCompletesThroughTheFallback() async throws {
        let esplora = try LocalRegtestEsplora(baseURL: localEndpoint())
        let context = try await makeContext(esplora: esplora)
        _ = try await esplora.fund(address: context.address, sats: 500_000)
        let recipient = try await esplora.newAddress(type: "bech32")
        let transfer = Self.transfer(sats: 200_000, recipient: recipient)
        try await esplora.reset()
        try await esplora.fault(service: "mempool", route: "any", mode: "429", count: 1000, retryAfter: 60)

        let fee = try await context.service.estimateFee(for: transfer)
        let txid = try await context.service.submit(transfer: transfer)

        let requests = try await esplora.requests()
        let primaryReads = (requests["mempool"] ?? []).filter { $0.hasPrefix("GET") }
        XCTAssertEqual(primaryReads.count, 1, "After the first 429 the primary is left alone: \(primaryReads)")
        XCTAssertTrue((requests["blockstream"] ?? []).contains("POST /tx"))
        let mempool = try await esplora.mempool()
        XCTAssertEqual(mempool, [txid])
        _ = try await esplora.mine(blocks: 1)
        let transaction = try await esplora.transaction(txid)
        XCTAssertEqual(transaction.fee, Int64(fee))
        XCTAssertEqual(transaction.vout.filter { $0.scriptpubkeyAddress == recipient }.map(\.value), [200_000])
    }

    /// Every recipient type the wallet supports receives exactly the amount sent, at exactly
    /// the quoted fee, with the change back on the wallet's own address.
    func testEveryPayableAddressType_receivesTheExactAmountAtTheQuotedFee() async throws {
        let esplora = try LocalRegtestEsplora(baseURL: localEndpoint())
        let context = try await makeContext(esplora: esplora)
        _ = try await esplora.fund(address: context.address, sats: 5_000_000)

        for type in ["legacy", "p2sh-segwit", "bech32", "p2wsh", "bech32m"] {
            let recipient = try await esplora.newAddress(type: type)
            let transfer = Self.transfer(sats: 100_000, recipient: recipient)

            let fee = try await context.service.estimateFee(for: transfer)
            let txid = try await context.service.submit(transfer: transfer)
            _ = try await esplora.mine(blocks: 1)

            let transaction = try await esplora.transaction(txid)
            XCTAssertTrue(transaction.status.confirmed, type)
            XCTAssertEqual(transaction.fee, Int64(fee), type)
            XCTAssertEqual(
                transaction.vout.filter { $0.scriptpubkeyAddress == recipient }.map(\.value),
                [100_000],
                "\(type) \(recipient)"
            )
            XCTAssertEqual(transaction.vout.filter { $0.scriptpubkeyAddress == context.address }.count, 1, type)
        }
    }

    /// Max with an unconfirmed incoming payment: the portfolio counts both coins, Send offers
    /// only the confirmed one, and sending all of it leaves no change and pays the shown fee.
    func testSendAll_spendsOnlyConfirmedCoinsWithoutChange() async throws {
        let esplora = try LocalRegtestEsplora(baseURL: localEndpoint())
        let context = try await makeContext(esplora: esplora)
        let confirmedCoin = try await esplora.fund(address: context.address, sats: 300_000)
        _ = try await esplora.fund(address: context.address, sats: 200_000, confirm: false)
        let recipient = try await esplora.newAddress(type: "bech32m")
        let balance = try await BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: context.client))
            .balance(mnemonic: context.mnemonic, network: .testnet)
        XCTAssertEqual(balance.totalSats, 500_000)
        XCTAssertEqual(balance.confirmedSpendableSats, 300_000)
        XCTAssertEqual(balance.pendingSats, 200_000)

        let maxFee = try await context.service.estimateFee(
            for: Self.transfer(sats: balance.confirmedSpendableSats, recipient: recipient)
        )
        let amount = balance.confirmedSpendableSats - Int64(maxFee)
        let transfer = Self.transfer(sats: amount, recipient: recipient)
        let fee = try await context.service.estimateFee(for: transfer)
        let txid = try await context.service.submit(transfer: transfer)

        XCTAssertEqual(fee, maxFee)
        let transaction = try await esplora.transaction(txid)
        XCTAssertEqual(transaction.vin.map(\.txid), [confirmedCoin])
        XCTAssertEqual(transaction.vout.count, 1, "No change output")
        XCTAssertEqual(transaction.vout.first?.scriptpubkeyAddress, recipient)
        XCTAssertEqual(transaction.vout.first?.value, amount)
        XCTAssertEqual(transaction.fee, Int64(fee))
    }

    // MARK: - Builders

    private struct Context {
        let mnemonic: String
        let address: String
        let wallet: MetaAccountModel
        let client: BitcoinIndexerClientProtocol
        let store: BitcoinPendingBroadcastStore
        let service: BitcoinTransferService

        var scope: BitcoinPendingBroadcastScope {
            BitcoinPendingBroadcastScope(walletId: wallet.metaId, chainId: UniversalWalletRegistry.bitcoinTestnet.chainId)
        }
    }

    private func makeContext(esplora: LocalRegtestEsplora) async throws -> Context {
        try await esplora.reset()
        // Start from an empty mempool, whatever the previous test left in it.
        _ = try await esplora.mine(blocks: 1)
        let mnemonic = try IRMnemonicCreator().randomMnemonic(.entropy128).toString()
        let account = try BitcoinKeyDerivation.deriveAccount(mnemonic: mnemonic, network: .testnet)
        let wallet = AccountGenerator.generateMetaAccount(with: [
            ChainAccountModel(
                chainId: UniversalWalletRegistry.bitcoinTestnet.chainId,
                accountId: account.publicKey,
                publicKey: account.publicKey,
                cryptoType: CryptoType.ecdsa.rawValue,
                ethereumBased: false
            )
        ])
        // The production failover client and endpoint list; only the transport is local.
        let client = BitcoinFailoverIndexerClient(
            client: BitcoinIndexerClient(transport: esplora.transport),
            health: BitcoinIndexerEndpointHealth()
        )
        let store = BitcoinPendingBroadcastStore(userDefaults: defaults, logger: nil)
        let service = BitcoinTransferService(
            wallet: wallet,
            chain: Self.bitcoinChain,
            client: client,
            mnemonicProvider: LocalChainMnemonicProvider(mnemonic: mnemonic),
            sendGate: .production,
            pendingStore: store,
            statusPolling: BitcoinSendService.StatusPolling(attempts: 2, interval: 0.3)
        )
        return Context(
            mnemonic: mnemonic,
            address: account.firstReceiveAddress,
            wallet: wallet,
            client: client,
            store: store,
            service: service
        )
    }

    private func localEndpoint() throws -> URL {
        let name = "FEARLESS_E2E_ESPLORA_URL"
        guard let value = ProcessInfo.processInfo.environment[name], let url = URL(string: value) else {
            throw XCTSkip("\(name) is not set; run scripts/test-local-chain-sends.sh to start the local chains")
        }
        guard url.scheme == "http", ["127.0.0.1", "localhost"].contains(url.host ?? "") else {
            XCTFail("\(name) must point at a local chain on 127.0.0.1, got \(value)")
            throw LocalChainError.notLocal(value)
        }
        return url
    }

    private func assertOutcomeUnknown(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ submit: () async throws -> String
    ) async throws -> String {
        do {
            let txid = try await submit()
            XCTFail("Expected the broadcast outcome to be unknown, got success \(txid)", file: file, line: line)
            throw LocalChainError.unexpectedRequest("success")
        } catch let TransferServiceError.bitcoinBroadcastOutcomeUnknown(txid) {
            return txid
        }
    }

    private func assertTransferError(
        _ expected: BitcoinTestTransferError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(BitcoinTestTransferError(error), expected, "\(error)", file: file, line: line)
        }
    }

    private static let btcAsset = AssetModel(
        id: "BTC",
        name: "Bitcoin",
        symbol: "BTC",
        precision: 8,
        isUtility: true,
        isNative: true
    )

    private static let bitcoinChain = ChainModel(
        rank: nil,
        disabled: false,
        chainId: UniversalWalletRegistry.bitcoinTestnet.chainId,
        parentId: nil,
        paraId: nil,
        name: "Bitcoin Testnet",
        assets: [btcAsset],
        xcm: nil,
        nodes: [],
        addressPrefix: 0,
        types: nil,
        icon: nil,
        options: [.testnet],
        externalApi: nil,
        selectedNode: nil,
        customNodes: nil,
        iosMinAppVersion: nil,
        identityChain: nil
    )

    private static func transfer(sats: Int64, recipient: String) -> Transfer {
        Transfer(
            chainAsset: ChainAsset(chain: bitcoinChain, asset: btcAsset),
            amount: BigUInt(UInt64(sats)),
            receiver: recipient,
            tip: nil,
            appId: nil
        )
    }
}

private enum LocalChainError: Error {
    case notLocal(String)
    case unexpectedRequest(String)
    case rpc(String)
    case timeout(String)
}

private struct LocalChainMnemonicProvider: BitcoinMnemonicProviding {
    let mnemonic: String

    func mnemonic(for _: MetaAccountModel, chain _: ChainModel) throws -> String? {
        mnemonic
    }
}

/// Points the app's real `BitcoinIndexerClient` at the regtest shim. Only requests for the
/// app's own testnet Esplora services are rewritten, each to its own simulated service on the
/// shim (`/svc/mempool`, `/svc/blockstream`); anything else is refused, so a test can never
/// reach a public indexer.
private struct LocalEsploraTransport: UniversalWalletHTTPTransport {
    static let services: [(upstream: String, service: String)] = [
        (BitcoinIndexerNetwork.testnet.baseURLs[0].absoluteString, "mempool"),
        (BitcoinIndexerNetwork.testnet.baseURLs[1].absoluteString, "blockstream")
    ]

    let localBaseURL: URL
    private let inner = URLSessionUniversalWalletHTTPTransport()

    func perform(_ request: URLRequest) async throws -> Data {
        guard let url = request.url?.absoluteString,
              let match = Self.services.first(where: { url.hasPrefix($0.upstream + "/") }),
              let local = URL(
                  string: localBaseURL.absoluteString + "/svc/\(match.service)" + url.dropFirst(match.upstream.count)
              )
        else {
            throw LocalChainError.unexpectedRequest(request.url?.absoluteString ?? "nil")
        }
        var redirected = request
        redirected.url = local
        return try await inner.perform(redirected)
    }
}

private struct LocalRegtestEsplora {
    struct Transaction: Decodable {
        struct Input: Decodable {
            let txid: String?
        }

        struct Output: Decodable {
            let scriptpubkeyAddress: String?
            let value: Int64

            private enum CodingKeys: String, CodingKey {
                case scriptpubkeyAddress = "scriptpubkey_address"
                case value
            }
        }

        let txid: String
        let fee: Int64?
        let vin: [Input]
        let vout: [Output]
        let status: BitcoinEsploraTxStatus
    }

    let baseURL: URL
    let transport: LocalEsploraTransport

    init(baseURL: URL) {
        self.baseURL = baseURL
        transport = LocalEsploraTransport(localBaseURL: baseURL)
    }

    func fund(address: String, sats: Int64) async throws -> String {
        struct Response: Decodable { let txid: String }
        let body = try JSONSerialization.data(withJSONObject: ["address": address, "sats": sats, "confirm": true])
        let response: Response = try await request("regtest/fund", method: "POST", body: body)
        return response.txid
    }

    func mine(blocks: Int) async throws -> [String] {
        let body = try JSONSerialization.data(withJSONObject: ["blocks": blocks])
        return try await request("regtest/mine", method: "POST", body: body)
    }

    func mempool() async throws -> [String] {
        try await request("regtest/mempool")
    }

    func fund(address: String, sats: Int64, confirm: Bool) async throws -> String {
        struct Response: Decodable { let txid: String }
        let body = try JSONSerialization.data(withJSONObject: ["address": address, "sats": sats, "confirm": confirm])
        let response: Response = try await request("regtest/fund", method: "POST", body: body)
        return response.txid
    }

    /// Makes `service` ("mempool", "blockstream" or "*") fail the next `count` requests of
    /// `route` ("broadcast", "lookup" for `/tx/...`, "read" for everything else, or "any").
    func fault(service: String, route: String, mode: String, count: Int = 1, retryAfter: Int? = nil) async throws {
        var fault: [String: Any] = ["service": service, "route": route, "mode": mode, "count": count]
        fault["retry_after"] = retryAfter
        let _: [String: String] = try await request(
            "regtest/faults",
            method: "POST",
            body: JSONSerialization.data(withJSONObject: fault)
        )
    }

    /// Clears every fault and the request log.
    func reset() async throws {
        let _: [String: String] = try await request("regtest/reset", method: "POST", body: Data("{}".utf8))
    }

    /// "METHOD /path" for every request each simulated service received since the last reset.
    func requests() async throws -> [String: [String]] {
        try await request("regtest/requests")
    }

    /// A node-wallet address of a Bitcoin Core address type ("legacy", "p2sh-segwit",
    /// "bech32", "bech32m") or "p2wsh", spelled for the wallet's testnet code.
    func newAddress(type: String) async throws -> String {
        struct Response: Decodable { let address: String }
        let body = try JSONSerialization.data(withJSONObject: ["type": type])
        let response: Response = try await request("regtest/address", method: "POST", body: body)
        return response.address
    }

    /// Hands a raw transaction to the node directly, as another wallet or a stale retry would.
    func broadcastRaw(_ txHex: String) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("tx"))
        request.httpMethod = "POST"
        request.httpBody = Data(txHex.utf8)
        return try String(decoding: await URLSessionUniversalWalletHTTPTransport().perform(request), as: UTF8.self)
    }

    func isKnown(_ txid: String) async -> Bool {
        (try? await transaction(txid)) != nil
    }

    func transaction(_ txid: String) async throws -> Transaction {
        try await request("tx/\(txid)")
    }

    func utxos(address: String) async throws -> [BitcoinEsploraUtxo] {
        try await request("address/\(address)/utxo")
    }

    private func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let data = try await URLSessionUniversalWalletHTTPTransport().perform(request)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

/// JSON-RPC helpers the tests use to fund wallets and to read the validator's own view of
/// balances and signatures; the app under test uses its own RPC client and balance reader.
private final class LocalSolanaValidator {
    let rpcURL: URL

    init(rpcURL: URL) {
        self.rpcURL = rpcURL
    }

    /// The runner records the controlled validator's genesis before XCTest begins. Never
    /// infer a retained payment's identity from an endpoint during recovery.
    func capturedNetwork() throws -> UniversalWalletRegistry.SolanaNetwork {
        let hash = try XCTUnwrap(ProcessInfo.processInfo.environment["FEARLESS_E2E_SOLANA_GENESIS_HASH"],
                                 "The local-chain runner must pin the private validator genesis")
        XCTAssertEqual(try SolanaRpcRoutes.normalizePublicKey(hash), hash)
        let registry = UniversalWalletRegistry.solanaMainnet
        return UniversalWalletRegistry.SolanaNetwork(id: "private-validator", genesisHash: hash,
            chainId: registry.chainId, name: "Private validator", indexerBaseURL: registry.indexerBaseURL,
            rpcURL: rpcURL, enabledByDefault: false, nativeAsset: registry.nativeAsset)
    }

    func airdrop(to address: String, lamports: Int64) async throws {
        let signature: String = try await call("requestAirdrop", [address, lamports])
        try await waitUntilConfirmed(signature)
    }

    func balance(of address: String) async throws -> Int64 {
        struct Balance: Decodable { let value: Int64 }
        let balance: Balance = try await call("getBalance", [address, ["commitment": "confirmed"]])
        return balance.value
    }

    func signatureCount(for address: String) async throws -> Int {
        struct Entry: Decodable { let signature: String }
        let entries: [Entry] = try await call("getSignaturesForAddress", [address, ["commitment": "confirmed"]])
        return entries.count
    }

    func waitUntilConfirmed(_ signature: String) async throws {
        struct Statuses: Decodable {
            struct Status: Decodable {
                let confirmationStatus: String?
                let err: LocalChainAnyJSON?
            }

            let value: [Status?]
        }
        for _ in 0 ..< 120 {
            let statuses: Statuses = try await call(
                "getSignatureStatuses",
                [[signature], ["searchTransactionHistory": true]]
            )
            if let status = statuses.value.first ?? nil,
               ["confirmed", "finalized"].contains(status.confirmationStatus ?? "") {
                guard status.err == nil else {
                    throw LocalChainError.rpc("transaction \(signature) failed")
                }
                return
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        throw LocalChainError.timeout(signature)
    }

    func tokenBalance(of tokenAccount: String) async throws -> Int64 {
        struct TokenBalance: Decodable {
            struct Value: Decodable { let amount: String }
            let value: Value
        }
        let balance: TokenBalance = try await call("getTokenAccountBalance", [tokenAccount, ["commitment": "confirmed"]])
        guard let amount = Int64(balance.value.amount) else {
            throw LocalChainError.rpc("token balance \(balance.value.amount)")
        }
        return amount
    }

    func rentExemptMinimum(dataLength: Int) async throws -> Int64 {
        try await call("getMinimumBalanceForRentExemption", [dataLength])
    }

    /// The confirmation level the validator reports, nil when it has never seen the signature.
    func signatureStatus(_ signature: String) async throws -> String? {
        struct Statuses: Decodable {
            struct Status: Decodable { let confirmationStatus: String? }
            let value: [Status?]
        }
        let statuses: Statuses = try await call("getSignatureStatuses", [[signature], ["searchTransactionHistory": true]])
        return (statuses.value.first ?? nil)?.confirmationStatus
    }

    private func call<T: Decodable>(_ method: String, _ params: [Any]) async throws -> T {
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params
        ])
        let data = try await URLSessionUniversalWalletHTTPTransport().perform(request)
        let envelope = try JSONDecoder().decode(LocalSolanaRpcEnvelope<T>.self, from: data)
        guard let result = envelope.result else {
            throw LocalChainError.rpc("\(method): \(envelope.error?.message ?? "no result")")
        }
        return result
    }
}

/// Controls `scripts/local-chains/solana_rpc_proxy.py`, which serves the validator as two RPC
/// nodes (`/svc/a-primary`, `/svc/b-secondary`) and fails on request like public nodes do.
private struct LocalSolanaProxy {
    let baseURL: URL

    var nodes: [URL] {
        [baseURL.appendingPathComponent("svc/a-primary"), baseURL.appendingPathComponent("svc/b-secondary")]
    }

    func fault(service: String, method: String, mode: String, count: Int = 1) async throws {
        _ = try await post("proxy/faults", ["service": service, "method": method, "mode": mode, "count": count])
    }

    func reset() async throws {
        _ = try await post("proxy/reset", [:])
    }

    /// The JSON-RPC methods each node was asked, in order.
    func requests() async throws -> [String: [String]] {
        let data = try await URLSessionUniversalWalletHTTPTransport().perform(URLRequest(url: baseURL.appendingPathComponent("proxy/requests")))
        return try JSONDecoder().decode([String: [String]].self, from: data)
    }

    private func post(_ path: String, _ body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await URLSessionUniversalWalletHTTPTransport().perform(request)
    }
}

private struct LocalSolanaRpcEnvelope<Result: Decodable>: Decodable {
    struct RpcError: Decodable {
        let message: String
    }

    let result: Result?
    let error: RpcError?
}

/// Accepts any JSON value; used only to tell a null `err` from a failure object.
private struct LocalChainAnyJSON: Decodable {
    init(from decoder: Decoder) throws {
        _ = try decoder.singleValueContainer()
    }
}

// MARK: - The app's Send and Confirm screens over the local validator

/// The app's Send module (view controller, presenter, interactor) over a transfer service bound
/// to the local validator. Continue opens the app's Confirm module over the same service. Only
/// what reaches outside the device is replaced: balances come from the validator, and the
/// address score and scam lookups answer nothing.
@MainActor
private final class LocalSendScreens {
    let send: SendViewController
    let presenter: SendPresenter
    let router: LocalSendRouter
    let balances: LocalValidatorBalances
    var wireframe: LocalConfirmWireframe { router.wireframe }

    init(wallet: MetaAccountModel, chainAsset: ChainAsset, service: TransferServiceProtocol, balances: LocalValidatorBalances) {
        self.balances = balances
        // The wallet the screens send from is the selected one, as in the app.
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        settings.applySetupResult(.success(wallet))
        let dependencies = SendDependencies(
            wallet: wallet,
            chainAsset: chainAsset,
            runtimeService: nil,
            existentialDepositService: NoExistentialDeposit(),
            equilibruimTotalBalanceService: nil,
            transferService: service,
            accountInfoFetching: NoAccountInfoFetching(),
            polkaswapService: nil,
            storageRequestPerformer: nil
        )
        let operationManager = fearless.OperationManagerFacade.sharedManager
        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let runtimeMetadataRepository: AsyncCoreDataRepositoryDefault<fearless.RuntimeMetadataItem, SSFAssetManagmentStorage.CDRuntimeMetadataItem> =
            SubstrateDataStorageFacade.shared.createAsyncRepository()
        let interactor = SendInteractor(
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: wallet
            ),
            operationManager: operationManager,
            scamInfoFetching: NoScamInfo(),
            chainAssetFetching: ChainAssetsFetching(
                chainRepository: AnyDataProviderRepository(chainRepository),
                operationQueue: OperationQueue()
            ),
            dependencyContainer: SendDepencyContainer(wallet: wallet, operationManager: operationManager),
            addressChainDefiner: AddressChainDefiner(
                operationManager: operationManager,
                chainModelRepository: AnyDataProviderRepository(chainRepository),
                wallet: wallet
            ),
            runtimeItemRepository: AsyncAnyRepository(runtimeMetadataRepository),
            accountInfoRemoteService: balances,
            prepareDependencies: { _ in dependencies }
        )
        router = LocalSendRouter(service: service, balances: balances, settings: settings)
        let dataValidatingFactory = SendDataValidatingFactory(presentable: router)
        presenter = SendPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            viewModelFactory: SendViewModelFactory(
                iconGenerator: UniversalIconGenerator(),
                accountScoreFetcher: NoAccountStatistics(),
                settings: SettingsManager.shared
            ),
            dataValidatingFactory: dataValidatingFactory,
            logger: Logger.shared,
            wallet: wallet,
            initialData: .chainAsset(chainAsset),
            selectedWalletSettings: settings
        )
        send = SendViewController(
            initialData: .chainAsset(chainAsset),
            output: presenter,
            localizationManager: LocalizationManager.shared
        )
        dataValidatingFactory.view = send
    }
}

/// Opens the app's Confirm module, built as `WalletSendConfirmViewFactory` builds it but over
/// the local service, and pushes it as the app's router does. Every sheet is recorded.
private final class LocalSendRouter: SendRouterInput {
    let wireframe = LocalConfirmWireframe()
    private(set) var confirm: WalletSendConfirmViewController?
    private(set) var sheets: [String] = []
    private let service: TransferServiceProtocol
    private let balances: LocalValidatorBalances
    private let settings: SelectedWalletSettings

    init(service: TransferServiceProtocol, balances: LocalValidatorBalances, settings: SelectedWalletSettings) {
        self.service = service
        self.balances = balances
        self.settings = settings
    }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheets.append("\(viewModel.title): \(viewModel.message ?? "")")
    }

    func presentFormWarning(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheets.append("warning \(viewModel.title): \(viewModel.message ?? "")")
    }

    func presentConfirm(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        call: SendConfirmTransferCall,
        scamInfo: ScamInfo?,
        feeViewModel: BalanceViewModelProtocol?,
        selection: SelectedWalletAuthority.Lease?
    ) {
        let operationManager = fearless.OperationManagerFacade.sharedManager
        let service = service
        let interactor = WalletSendConfirmInteractor(
            selectedMetaAccount: wallet,
            chainAsset: chainAsset,
            call: call,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: wallet
            ),
            dependencyContainer: SendDepencyContainer(wallet: wallet, operationManager: operationManager),
            wallet: wallet,
            accountInfoRemoteService: balances,
            prepareTransferService: { _ in service },
            selectedWalletSettings: settings,
            selection: selection
        )
        let dataValidatingFactory = SendDataValidatingFactory(presentable: wireframe)
        let presenter = WalletSendConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            accountViewModelFactory: AccountViewModelFactory(iconGenerator: UniversalIconGenerator()),
            dataValidatingFactory: dataValidatingFactory,
            walletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactory(
                amountFormatterFactory: AssetBalanceFormatterFactory(),
                assetInfo: chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
            ),
            logger: Logger.shared,
            chainAsset: chainAsset,
            wallet: wallet,
            call: call,
            scamInfo: scamInfo,
            feeViewModel: feeViewModel,
            localizationManager: LocalizationManager.shared
        )
        let controller = WalletSendConfirmViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        dataValidatingFactory.view = controller
        presenter.view = controller
        interactor.presenter = presenter
        confirm = controller
        view?.controller.navigationController?.pushViewController(controller, animated: false)
    }

    func presentScan(from _: ControllerBackedProtocol?, moduleOutput _: ScanQRModuleOutput) {}
    func presentHistory(from _: ControllerBackedProtocol?, wallet _: MetaAccountModel, chainAsset _: ChainAsset, moduleOutput _: ContactsModuleOutput) {}
    func showSelectNetwork(
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        selectedChainId _: ChainModel.Id?,
        chainModels _: [ChainModel]?,
        delegate _: SelectNetworkDelegate?
    ) {}
    func showSelectAsset(
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        selectedAssetId _: AssetModel.Id?,
        chainAssets _: [ChainAsset]?,
        output _: SelectAssetModuleOutput
    ) {}
    func showManageAsset(from _: ControllerBackedProtocol?, wallet _: MetaAccountModel) {}
}

/// Records how the Confirm module ends instead of presenting the receipt.
private final class LocalConfirmWireframe: WalletSendConfirmWireframeProtocol {
    private(set) var completedHash: String?
    private(set) var sheets: [String] = []

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheets.append("\(viewModel.title): \(viewModel.message ?? "")")
    }

    func close(view _: ControllerBackedProtocol?) {
        sheets.append("closed")
    }

    func finish(view _: ControllerBackedProtocol?) {
        sheets.append("finished")
    }

    func complete(on _: ControllerBackedProtocol?, title: String, chainAsset _: ChainAsset) {
        completedHash = title
    }
}

/// The wallet's SOL balance as the local validator reports it.
private final class LocalValidatorBalances: AccountInfoRemoteService {
    private let validator: LocalSolanaValidator
    private let address: String
    private let lock = NSLock()
    private var readCount = 0

    init(validator: LocalSolanaValidator, address: String) {
        self.validator = validator
        self.address = address
    }

    var reads: Int {
        lock.lock()
        defer { lock.unlock() }
        return readCount
    }

    func fetchAccountInfos(for chain: ChainModel, wallet: MetaAccountModel) async throws -> [ChainAssetId: AccountInfo?] {
        var infos: [ChainAssetId: AccountInfo?] = [:]
        for chainAsset in chain.chainAssets {
            infos[chainAsset.chainAssetId] = try await fetchAccountInfo(for: chainAsset, wallet: wallet)
        }
        return infos
    }

    func fetchAccountInfo(for chainAsset: ChainAsset, wallet _: MetaAccountModel) async throws -> AccountInfo? {
        let lamports = try await validator.balance(of: address)
        lock.lock()
        readCount += 1
        lock.unlock()
        return chainAsset.asset.isUtility ? AccountInfo(ethBalance: BigUInt(UInt64(lamports))) : nil
    }
}

private struct NoExistentialDeposit: ExistentialDepositServiceProtocol {
    func fetchExistentialDeposit(chainAsset _: ChainAsset, completion: @escaping (Result<BigUInt, Error>) -> Void) {
        completion(.success(.zero))
    }
}

private struct NoAccountInfoFetching: AccountInfoFetchingProtocol {
    func fetch(for chainAsset: ChainAsset, accountId _: AccountId, completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void) {
        completionBlock(chainAsset, nil)
    }

    func fetch(for _: [ChainAsset], wallet _: MetaAccountModel, completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void) {
        completionBlock([:])
    }

    func fetch(for chainAsset: ChainAsset, accountId _: AccountId) async throws -> (ChainAsset, AccountInfo?) {
        (chainAsset, nil)
    }

    func fetch(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAsset: AccountInfo?] {
        [:]
    }

    func fetchByUniqKey(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAssetKey: AccountInfo?] {
        [:]
    }
}

private struct NoScamInfo: ScamInfoFetching {
    func fetch(address _: String, chain _: ChainModel) async throws -> ScamInfo? {
        nil
    }
}

private struct NoAccountStatistics: AccountStatisticsFetching {
    func subscribeForStatistics(address _: String) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? {
        nil
    }
}

