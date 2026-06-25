import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class BitcoinHistoryOperationFactoryTests: XCTestCase {
    func testAssemblyRoutesBitcoinChainsToBitcoinHistoryFactory() {
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()
        let repository = AnyDataProviderRepository(txStorage)

        let mainnetFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
            chain: Self.bitcoinChain(),
            txStorage: repository
        )
        let testnetFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
            chain: Self.bitcoinChain(chainId: UniversalWalletRegistry.bitcoinTestnet.chainId),
            txStorage: repository
        )
        let registryMainnetFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
            chain: Self.bitcoinChain(chainId: UniversalWalletRegistry.bitcoinMainnet.id),
            txStorage: repository
        )
        let registryTestnetFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
            chain: Self.bitcoinChain(chainId: UniversalWalletRegistry.bitcoinTestnet.id),
            txStorage: repository
        )

        XCTAssertTrue(mainnetFactory is BitcoinHistoryOperationFactory)
        XCTAssertTrue(testnetFactory is BitcoinHistoryOperationFactory)
        XCTAssertTrue(registryMainnetFactory is BitcoinHistoryOperationFactory)
        XCTAssertTrue(registryTestnetFactory is BitcoinHistoryOperationFactory)
    }

    func testMapsBitcoinHistoryIntoWalletTransactionPage() throws {
        let client = FakeBitcoinIndexerClient(
            transactionProvider: { cursor in
                XCTAssertNil(cursor)
                return [
                    Self.outgoingTransaction(
                        txid: Self.txid1,
                        fee: 141,
                        blockTime: 1_710_000_000
                    ),
                    Self.incomingTransaction(
                        txid: Self.txid2,
                        confirmed: false,
                        blockTime: nil
                    )
                ]
            }
        )

        let result = try execute(
            BitcoinHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.btcAsset,
                chain: Self.bitcoinChain(),
                address: Self.mainnetAddress,
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: Pagination(count: 10)
            )
        )

        let page = try XCTUnwrap(result)
        XCTAssertEqual(client.calls, 1)
        XCTAssertEqual(client.lastAddress, Self.mainnetAddress)
        XCTAssertEqual(client.lastNetwork, .mainnet)
        XCTAssertNil(client.lastBaseURL)
        XCTAssertEqual(page.transactions.count, 2)
        XCTAssertNil(page.context)

        let outgoing = page.transactions[0]
        XCTAssertEqual(outgoing.transactionId, Self.txid1)
        XCTAssertEqual(outgoing.status, .commited)
        XCTAssertEqual(outgoing.assetId, "BTC")
        XCTAssertEqual(outgoing.peerId, Self.counterparty)
        XCTAssertEqual(outgoing.peerName, Self.counterparty)
        XCTAssertEqual(outgoing.amount.decimalValue, Decimal(string: "0.0006"))
        XCTAssertEqual(outgoing.fees.first?.amount.decimalValue, Decimal(string: "0.00000141"))
        XCTAssertEqual(outgoing.timestamp, 1_710_000_000)
        XCTAssertEqual(outgoing.type, TransactionType.outgoing.rawValue)

        let incoming = page.transactions[1]
        XCTAssertEqual(incoming.transactionId, Self.txid2)
        XCTAssertEqual(incoming.status, .pending)
        XCTAssertEqual(incoming.amount.decimalValue, Decimal(string: "0.00075"))
        XCTAssertTrue(incoming.fees.isEmpty)
        XCTAssertEqual(incoming.type, TransactionType.incoming.rawValue)
    }

    func testUsesPaginationContextAndLimitsReturnedTransactions() throws {
        let client = FakeBitcoinIndexerClient(
            transactionProvider: { cursor in
                if cursor == Self.txid0 {
                    return [
                        Self.outgoingTransaction(txid: Self.txid1),
                        Self.outgoingTransaction(txid: Self.txid2)
                    ]
                }

                return []
            }
        )

        let result = try execute(
            BitcoinHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.btcAsset,
                chain: Self.bitcoinChain(),
                address: Self.mainnetAddress,
                filters: [],
                pagination: Pagination(
                    count: 1,
                    context: [BitcoinHistoryOperationFactory.paginationLastSeenTxidKey: Self.txid0]
                )
            )
        )

        let page = try XCTUnwrap(result)
        XCTAssertEqual(client.calls, 1)
        XCTAssertEqual(client.lastSeenTxids, [Self.txid0])
        XCTAssertEqual(page.transactions.map(\.transactionId), [Self.txid1])
        XCTAssertEqual(page.context?[BitcoinHistoryOperationFactory.paginationLastSeenTxidKey], Self.txid1)
    }

    func testGuardPathsAvoidIndexerCalls() throws {
        let filters = [WalletTransactionHistoryFilter(type: .reward, selected: true)]
        let unsupportedAsset = AssetModel(
            id: "USDT",
            name: "Tether",
            symbol: "USDT",
            precision: 6,
            isUtility: false,
            isNative: false
        )

        for (asset, pagination, filterSet) in [
            (unsupportedAsset, Pagination(count: 10), [WalletTransactionHistoryFilter(type: .transfer, selected: true)]),
            (Self.btcAsset, Pagination(count: 0), [WalletTransactionHistoryFilter(type: .transfer, selected: true)]),
            (Self.btcAsset, Pagination(count: 10), filters)
        ] {
            let client = FakeBitcoinIndexerClient()
            let result = try execute(
                BitcoinHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                    asset: asset,
                    chain: Self.bitcoinChain(),
                    address: Self.mainnetAddress,
                    filters: filterSet,
                    pagination: pagination
                )
            )

            XCTAssertEqual(client.calls, 0)
            XCTAssertEqual(result?.transactions, [])
            XCTAssertNil(result?.context)
        }
    }

    func testWrongNetworkAddressReturnsEmptyPageBeforeNetworkCall() throws {
        let client = FakeBitcoinIndexerClient()

        let result = try execute(
            BitcoinHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.btcAsset,
                chain: Self.bitcoinChain(),
                address: Self.testnetAddress,
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: Pagination(count: 10)
            )
        )

        XCTAssertEqual(client.calls, 0)
        XCTAssertEqual(result?.transactions, [])
        XCTAssertNil(result?.context)
    }

    func testIndexerOutageReturnsEmptyPage() throws {
        let client = FakeBitcoinIndexerClient(error: TestError.indexerUnavailable)

        let result = try execute(
            BitcoinHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.btcAsset,
                chain: Self.bitcoinChain(),
                address: Self.mainnetAddress,
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: Pagination(count: 10)
            )
        )

        XCTAssertEqual(client.calls, 1)
        XCTAssertEqual(result?.transactions, [])
        XCTAssertNil(result?.context)
    }

    func testTestnetChainUsesTestnetAddressAndNetwork() throws {
        let client = FakeBitcoinIndexerClient(
            transactions: [Self.testnetIncomingTransaction(txid: Self.txid1)]
        )

        let result = try execute(
            BitcoinHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.btcAsset,
                chain: Self.bitcoinChain(chainId: UniversalWalletRegistry.bitcoinTestnet.chainId),
                address: Self.testnetAddress,
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: Pagination(count: 10)
            )
        )

        XCTAssertEqual(client.calls, 1)
        XCTAssertEqual(client.lastNetwork, .testnet)
        XCTAssertEqual(result?.transactions.first?.transactionId, Self.txid1)
    }

    func testRegistryIdTestnetChainUsesTestnetAddressAndNetwork() throws {
        let client = FakeBitcoinIndexerClient(
            transactions: [Self.testnetIncomingTransaction(txid: Self.txid1)]
        )

        let result = try execute(
            BitcoinHistoryOperationFactory(client: client).fetchTransactionHistoryOperation(
                asset: Self.btcAsset,
                chain: Self.bitcoinChain(chainId: UniversalWalletRegistry.bitcoinTestnet.id),
                address: Self.testnetAddress,
                filters: [WalletTransactionHistoryFilter(type: .transfer, selected: true)],
                pagination: Pagination(count: 10)
            )
        )

        XCTAssertEqual(client.calls, 1)
        XCTAssertEqual(client.lastNetwork, .testnet)
        XCTAssertEqual(result?.transactions.first?.transactionId, Self.txid1)
    }

    private func execute(
        _ wrapper: CompoundOperationWrapper<AssetTransactionPageData?>
    ) throws -> AssetTransactionPageData? {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }

    private final class FakeBitcoinIndexerClient: BitcoinIndexerClientProtocol {
        private let transactionsResponse: [BitcoinEsploraTransaction]
        private let transactionProvider: ((String?) -> [BitcoinEsploraTransaction])?
        private let error: Error?

        private(set) var calls = 0
        private(set) var lastAddress: String?
        private(set) var lastNetwork: BitcoinIndexerNetwork?
        private(set) var lastBaseURL: String?
        private(set) var lastSeenTxids: [String?] = []

        init(
            transactions: [BitcoinEsploraTransaction] = [],
            transactionProvider: ((String?) -> [BitcoinEsploraTransaction])? = nil,
            error: Error? = nil
        ) {
            transactionsResponse = transactions
            self.transactionProvider = transactionProvider
            self.error = error
        }

        func address(
            address _: String,
            network _: BitcoinIndexerNetwork,
            baseURL _: String?
        ) async throws -> BitcoinEsploraAddress {
            fatalError("Not used")
        }

        func utxos(
            address _: String,
            network _: BitcoinIndexerNetwork,
            baseURL _: String?
        ) async throws -> [BitcoinEsploraUtxo] {
            fatalError("Not used")
        }

        func transactions(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?,
            lastSeenTxid: String?,
            mempool _: Bool
        ) async throws -> [BitcoinEsploraTransaction] {
            calls += 1
            lastAddress = address
            lastNetwork = network
            lastBaseURL = baseURL
            lastSeenTxids.append(lastSeenTxid)

            if let error {
                throw error
            }

            return transactionProvider?(lastSeenTxid) ?? transactionsResponse
        }

        func feeEstimates(
            network _: BitcoinIndexerNetwork,
            baseURL _: String?
        ) async throws -> [String: Double] {
            fatalError("Not used")
        }

        func broadcastTransaction(
            txHex _: String,
            network _: BitcoinIndexerNetwork,
            baseURL _: String?
        ) async throws -> String {
            fatalError("Not used")
        }
    }

    private enum TestError: Error {
        case indexerUnavailable
    }

    private static let mainnetAddress = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
    private static let testnetAddress = "tb1q6rz28mcfaxtmd6v789l9rrlrusdprr9pqcpvkl"
    private static let counterparty = "bc1q6rz28mcfaxtmd6v789l9rrlrusdprr9pkv76kj"
    private static let testnetCounterparty = "tb1qcr8te4kr609gcawutmrza0j4xv80jy8z69lhm6"
    private static let txid0 = String(repeating: "00", count: 32)
    private static let txid1 = String(repeating: "11", count: 32)
    private static let txid2 = String(repeating: "22", count: 32)

    private static let btcAsset = AssetModel(
        id: "BTC",
        name: "Bitcoin",
        symbol: "BTC",
        precision: 8,
        isUtility: true,
        isNative: true
    )

    private static func bitcoinChain(
        chainId: String = UniversalWalletRegistry.bitcoinMainnet.chainId
    ) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "https://node.example")!,
            name: "Bitcoin",
            apikey: nil
        )

        let testnetChainIds = [
            UniversalWalletRegistry.bitcoinTestnet.chainId,
            UniversalWalletRegistry.bitcoinTestnet.id
        ]
        let options: [ChainOptions]? = testnetChainIds.contains(chainId) ? [.testnet] : nil

        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: testnetChainIds.contains(chainId) ? "Bitcoin Testnet" : "Bitcoin",
            assets: [btcAsset],
            xcm: nil,
            nodes: [node],
            addressPrefix: 0,
            icon: nil,
            options: options,
            externalApi: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )

        return chain
    }

    private static func outgoingTransaction(
        txid: String,
        fee: Int64 = 100,
        blockTime: Int64 = 1_710_000_000
    ) -> BitcoinEsploraTransaction {
        transaction(
            txid: txid,
            fee: fee,
            status: BitcoinEsploraTxStatus(
                confirmed: true,
                blockHash: String(repeating: "aa", count: 32),
                blockHeight: 100,
                blockTime: blockTime
            ),
            vin: [input(mainnetAddress, 100_000)],
            vout: [output(counterparty, 60_000), output(mainnetAddress, 39_859)]
        )
    }

    private static func incomingTransaction(
        txid: String,
        confirmed: Bool = true,
        blockTime: Int64?
    ) -> BitcoinEsploraTransaction {
        transaction(
            txid: txid,
            fee: 200,
            status: BitcoinEsploraTxStatus(
                confirmed: confirmed,
                blockHash: confirmed ? String(repeating: "bb", count: 32) : nil,
                blockHeight: confirmed ? 101 : nil,
                blockTime: blockTime
            ),
            vin: [input(counterparty, 75_200)],
            vout: [output(mainnetAddress, 75_000)]
        )
    }

    private static func testnetIncomingTransaction(txid: String) -> BitcoinEsploraTransaction {
        transaction(
            txid: txid,
            fee: 200,
            vin: [BitcoinEsploraTransactionInput(prevout: output(testnetCounterparty, 75_200))],
            vout: [output(testnetAddress, 75_000)]
        )
    }

    private static func transaction(
        txid: String,
        fee: Int64? = nil,
        status: BitcoinEsploraTxStatus = BitcoinEsploraTxStatus(
            confirmed: true,
            blockHash: nil,
            blockHeight: nil,
            blockTime: nil
        ),
        vin: [BitcoinEsploraTransactionInput],
        vout: [BitcoinEsploraTransactionOutput]
    ) -> BitcoinEsploraTransaction {
        BitcoinEsploraTransaction(
            txid: txid,
            status: status,
            fee: fee,
            vin: vin,
            vout: vout
        )
    }

    private static func input(_ address: String, _ value: Int64) -> BitcoinEsploraTransactionInput {
        BitcoinEsploraTransactionInput(prevout: output(address, value))
    }

    private static func output(_ address: String, _ value: Int64) -> BitcoinEsploraTransactionOutput {
        BitcoinEsploraTransactionOutput(scriptPubKeyAddress: address, value: value)
    }
}
