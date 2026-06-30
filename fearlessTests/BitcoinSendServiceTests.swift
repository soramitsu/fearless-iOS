import XCTest
import BigInt
import SSFModels
@testable import fearless

final class BitcoinSendServiceTests: XCTestCase {
    func testPreparesSignedTransactionFromSelectedUtxosWithoutBroadcasting() async throws {
        let client = FakeBitcoinIndexerClient()
        let prepared = try await BitcoinSendService(client: client).prepare(Self.request())

        XCTAssertEqual(prepared.plan.feeSats, 282)
        XCTAssertEqual(prepared.plan.changeSats, 49_718)
        XCTAssertEqual(prepared.transaction.txid, Self.expectedTxid)
        XCTAssertEqual(prepared.transaction.txHex, Self.expectedTxHex)
        XCTAssertNil(client.lastBroadcastTxHex)
    }

    func testSendsSignedTransactionAndRequiresMatchingBroadcastTxid() async throws {
        let client = FakeBitcoinIndexerClient(broadcastResponse: Self.expectedTxid.uppercased())
        let result = try await BitcoinSendService(client: client).send(Self.request(baseURL: "https://bitcoin.example/api"))

        XCTAssertEqual(result.broadcastTxid, Self.expectedTxid)
        XCTAssertEqual(result.prepared.transaction.txid, Self.expectedTxid)
        XCTAssertEqual(client.lastBroadcastTxHex, Self.expectedTxHex)
        XCTAssertEqual(client.lastBroadcastNetwork, .mainnet)
        XCTAssertEqual(client.lastBroadcastBaseURL, "https://bitcoin.example/api")
    }

    func testRejectsBroadcastTxidMismatches() async {
        let client = FakeBitcoinIndexerClient(broadcastResponse: String(repeating: "22", count: 32))

        do {
            _ = try await BitcoinSendService(client: client).send(Self.request())
            XCTFail("Expected Bitcoin send service txid mismatch")
        } catch {
            XCTAssertEqual(error as? BitcoinSendServiceError, .broadcastTxidMismatch)
        }
    }

    func testBitcoinTransferServiceEstimatesFeeAndSendsFromUniversalWalletAccount() async throws {
        let chain = Self.bitcoinChain(historyBaseURL: "https://bitcoin.example/api")
        let wallet = try Self.walletWithBitcoinAccount(
            chainId: UniversalWalletRegistry.bitcoinMainnet.id,
            network: .mainnet
        )
        let client = FakeBitcoinIndexerClient(broadcastResponse: Self.expectedTxid.uppercased())
        let service = BitcoinTransferService(
            wallet: wallet,
            chain: chain,
            client: client,
            mnemonicProvider: FakeBitcoinMnemonicProvider(mnemonic: Self.mnemonic)
        )
        let transfer = Self.transfer(chain: chain)

        let fee = try await service.estimateFee(for: transfer)
        let txid = try await service.submit(transfer: transfer)

        XCTAssertEqual(fee, BigUInt(282))
        XCTAssertEqual(txid, Self.expectedTxid)
        XCTAssertEqual(client.lastFeeNetwork, .mainnet)
        XCTAssertEqual(client.lastFeeBaseURL, "https://bitcoin.example/api")
        XCTAssertEqual(client.lastUtxosAddress, Self.mainnetAddress)
        XCTAssertEqual(client.lastUtxosNetwork, .mainnet)
        XCTAssertEqual(client.lastUtxosBaseURL, "https://bitcoin.example/api")
        XCTAssertEqual(client.lastBroadcastTxHex, Self.expectedTxHex)
        XCTAssertEqual(client.lastBroadcastNetwork, .mainnet)
        XCTAssertEqual(client.lastBroadcastBaseURL, "https://bitcoin.example/api")
    }

    func testBitcoinTransferServiceRejectsMissingMnemonicRootMaterial() async throws {
        let chain = Self.bitcoinChain()
        let wallet = try Self.walletWithBitcoinAccount(chainId: UniversalWalletRegistry.bitcoinMainnet.chainId)
        let client = FakeBitcoinIndexerClient()
        let service = BitcoinTransferService(
            wallet: wallet,
            chain: chain,
            client: client,
            mnemonicProvider: FakeBitcoinMnemonicProvider(mnemonic: nil)
        )

        do {
            _ = try await service.submit(transfer: Self.transfer(chain: chain))
            XCTFail("Expected Bitcoin transfer service to reject missing mnemonic material")
        } catch TransferServiceError.transferFailed(let reason) {
            XCTAssertTrue(reason.contains("mnemonic"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertNil(client.lastFeeNetwork)
        XCTAssertNil(client.lastUtxosAddress)
        XCTAssertNil(client.lastBroadcastTxHex)
    }

    func testBitcoinTransferServiceRejectsMnemonicMismatchBeforeIndexerCalls() async throws {
        let chain = Self.bitcoinChain(historyBaseURL: "https://bitcoin.example/api")
        let wallet = try Self.walletWithBitcoinAccount(chainId: UniversalWalletRegistry.bitcoinMainnet.chainId)
        let client = FakeBitcoinIndexerClient()
        let service = BitcoinTransferService(
            wallet: wallet,
            chain: chain,
            client: client,
            mnemonicProvider: FakeBitcoinMnemonicProvider(mnemonic: Self.otherMnemonic)
        )

        do {
            _ = try await service.submit(transfer: Self.transfer(chain: chain))
            XCTFail("Expected Bitcoin transfer service to reject mismatched mnemonic material")
        } catch TransferServiceError.transferFailed(let reason) {
            XCTAssertTrue(reason.contains("does not match selected wallet"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertNil(client.lastFeeNetwork)
        XCTAssertNil(client.lastUtxosAddress)
        XCTAssertNil(client.lastBroadcastTxHex)
    }

    private final class FakeBitcoinIndexerClient: BitcoinIndexerClientProtocol {
        private let broadcastResponse: String
        private(set) var lastBroadcastTxHex: String?
        private(set) var lastBroadcastNetwork: BitcoinIndexerNetwork?
        private(set) var lastBroadcastBaseURL: String?
        private(set) var lastFeeNetwork: BitcoinIndexerNetwork?
        private(set) var lastFeeBaseURL: String?
        private(set) var lastUtxosAddress: String?
        private(set) var lastUtxosNetwork: BitcoinIndexerNetwork?
        private(set) var lastUtxosBaseURL: String?

        init(broadcastResponse: String = BitcoinSendServiceTests.expectedTxid) {
            self.broadcastResponse = broadcastResponse
        }

        func address(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> BitcoinEsploraAddress {
            fatalError("Not used")
        }

        func utxos(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> [BitcoinEsploraUtxo] {
            lastUtxosAddress = address
            lastUtxosNetwork = network
            lastUtxosBaseURL = baseURL

            return [
                BitcoinEsploraUtxo(
                    txid: BitcoinSendServiceTests.txid,
                    vout: 1,
                    value: 100_000,
                    status: BitcoinEsploraTxStatus(confirmed: true, blockHash: nil, blockHeight: nil, blockTime: nil)
                )
            ]
        }

        func transactions(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?,
            lastSeenTxid: String?,
            mempool: Bool
        ) async throws -> [BitcoinEsploraTransaction] {
            return []
        }

        func feeEstimates(
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> [String: Double] {
            lastFeeNetwork = network
            lastFeeBaseURL = baseURL

            return ["2": 2]
        }

        func broadcastTransaction(
            txHex: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> String {
            lastBroadcastTxHex = txHex
            lastBroadcastNetwork = network
            lastBroadcastBaseURL = baseURL

            return broadcastResponse
        }
    }

    private struct FakeBitcoinMnemonicProvider: BitcoinMnemonicProviding {
        let mnemonic: String?

        func mnemonic(for _: MetaAccountModel, chain _: ChainModel) throws -> String? {
            mnemonic
        }
    }

    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let otherMnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
    private static let mainnetAddress = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
    private static let mainnetRecipient = "bc1qslk39wvggqa0vl8nd6jckaz54dw3vk45c5w60m"
    private static let txid = String(repeating: "11", count: 32)
    private static let expectedTxid = "94c9b9d5070f24e06725b1000d9b1a0d46473d07b59088aca35e3d3da345023d"
    private static let expectedTxHex = "0200000000010111111111111111111111111111111111111111111111111111111111111111110100000000ffffffff0250c300000000000016001487ed12b988403af67cf36ea58b7454ab5d165ab436c2000000000000160014c0cebcd6c3d3ca8c75dc5ec62ebe55330ef910e202473044022009ec0c24a20c4346c6516065723e2e83e6a7e4dd278fb66e27f36d9108d7ef4c022077f115bfbd68a2bc7a4c100766d9cceaf5300bcfcdc775be0248e7fb5a58216801210330d54fd0dd420a6e5f8d3624f5f3482cae350f79d5f0753bf5beef9c2d91af3c00000000"
    private static let asset = AssetModel(
        id: "BTC",
        name: "Bitcoin",
        symbol: "BTC",
        precision: 8,
        isUtility: true,
        isNative: true
    )

    private static func request(baseURL: String? = nil) -> BitcoinSendRequest {
        BitcoinSendRequest(
            mnemonic: mnemonic,
            amountSats: 50_000,
            sources: [BitcoinUtxoSource(address: mainnetAddress)],
            recipientAddress: mainnetRecipient,
            changeAddress: mainnetAddress,
            feeRateSatPerVbyte: 2,
            baseURL: baseURL
        )
    }

    private static func transfer(chain: ChainModel) -> Transfer {
        Transfer(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            amount: BigUInt(50_000),
            receiver: mainnetRecipient,
            tip: nil,
            appId: nil
        )
    }

    private static func walletWithBitcoinAccount(
        chainId: String,
        network: BitcoinKeyDerivation.Network = .mainnet
    ) throws -> MetaAccountModel {
        let account = try BitcoinKeyDerivation.deriveAccount(mnemonic: mnemonic, network: network)
        let chainAccount = ChainAccountModel(
            chainId: chainId,
            accountId: account.publicKey,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ecdsa.rawValue,
            ethereumBased: false
        )

        return AccountGenerator.generateMetaAccount(with: [chainAccount])
    }

    private static func bitcoinChain(
        chainId: String = UniversalWalletRegistry.bitcoinMainnet.chainId,
        historyBaseURL: String? = nil
    ) -> ChainModel {
        let externalApi = historyBaseURL.map {
            ChainModel.ExternalApiSet(
                staking: nil,
                history: ChainModel.BlockExplorer(
                    type: "subsquid",
                    url: URL(string: $0)!
                ),
                crowdloans: nil,
                explorers: nil
            )
        }

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: "Bitcoin",
            assets: [asset],
            xcm: nil,
            nodes: [
                ChainNodeModel(
                    url: URL(string: "https://bitcoin.node.example")!,
                    name: "Bitcoin",
                    apikey: nil
                )
            ],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: externalApi,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}
