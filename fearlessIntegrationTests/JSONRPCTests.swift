import XCTest
@testable import fearless
import FearlessUtils
import RobinHood
import IrohaCrypto
import BigInt
import xxHash_Swift
import SoraKeystore
import SoraFoundation

class JSONRPCTests: XCTestCase {
    struct RpcInterface: Decodable {
        let version: Int
        let methods: [String]
    }

    func testGetMethods() {
        // given

        let url = URL(string: "wss://kusama-rpc.polkadot.io")!
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let operation = JSONRPCListOperation<RpcInterface>(engine: engine,
                                                           method: "rpc_methods")

        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            logger.debug("Received response: \(result.methods)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetBlockHash() throws {
        // given

        var block: UInt32 = 10000

        let url = URL(string: "wss://kusama-rpc.polkadot.io")!
        let logger = Logger.shared

        let data = Data(Data(bytes: &block, count: MemoryLayout<UInt32>.size).reversed())

        // when

        let engine = WebSocketEngine(url: url, logger: logger)

        let operation = JSONRPCListOperation<String?>(engine: engine,
                                                      method: RPCMethod.getBlockHash,
                                                      parameters: [data.toHex(includePrefix: true)])

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            logger.debug("Received response: \(result!)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNetworkType() {
        // given

        let url = URL(string: "wss://westend-rpc.polkadot.io/")!
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let operation = JSONRPCListOperation<String>(engine: engine,
                                                     method: "system_chain")

        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            logger.debug("Received response: \(result)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testHelthCheck() {
        // given

        let url = URL(string: "wss://westend-rpc.polkadot.io/")!
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let operation = JSONRPCListOperation<Health>(engine: engine,
                                                     method: "system_health")

        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            logger.debug("Received response: \(result)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNonceFetch() {
        // given

        let url = URL(string: "wss://westend-rpc.polkadot.io/")!
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let address = "5CDayXd3cDCWpBkSXVsVfhE5bWKyTZdD3D1XUinR1ezS1sGn"
        let operation = JSONRPCListOperation<UInt32>(engine: engine,
                                                     method: RPCMethod.getExtrinsicNonce,
                                                     parameters: [address])

        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            logger.debug("Received response: \(result)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBlockExtraction() throws {
        // given

        let url = URL(string: "wss://westend-rpc.polkadot.io/")!
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let blockHash = "0xd843c9d2b49489653a4310aa9f2e5593ced253ad7fdc325e00fb6f28e7fc0ce8"

        let operation = JSONRPCListOperation<[String: String]>(engine: engine,
                                                               method: "chain_getBlock",
                                                               parameters: [blockHash])

        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            logger.debug("Received response: \(result)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPolkadotActiveEra() {
        performGetActiveEra(url: URL(string: "wss://rpc.polkadot.io/")!)
    }

    func performGetActiveEra(url: URL) {
        // given

        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let storageFactory = StorageKeyFactory()
        let key = try! storageFactory
            .createStorageKey(moduleName: "Staking", storageName: "ActiveEra")
            .toHex(includePrefix: true)

        let operation = JSONRPCListOperation<JSONScaleDecodable<UInt32>>(engine: engine,
                                                                         method: RPCMethod.getStorage,
                                                                         parameters: [key])

        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard let activeEra = result.underlyingValue else {
                XCTFail("Empty Active Era")
                return
            }

            Logger.shared.debug("Active Era: \(activeEra)")

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPolkadotCurrentEra() {
        performGetCurrentEra(url: URL(string: "wss://rpc.polkadot.io/")!)
    }

    func performGetCurrentEra(url: URL) {
        // given

        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let storageFactory = StorageKeyFactory()
        let key = try! storageFactory
            .createStorageKey(moduleName: "Staking", storageName: "CurrentEra")
            .toHex(includePrefix: true)

        let operation = JSONRPCListOperation<JSONScaleDecodable<UInt32>>(engine: engine,
                                                                         method: RPCMethod.getStorage,
                                                                         parameters: [key])

        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard let currentEra = result.underlyingValue else {
                XCTFail("Empty Current Era")
                return
            }

            Logger.shared.debug("Current Era: \(currentEra)")

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetRuntimeVersion() {
        // given

        let url = URL(string: "wss://ws.validator.dev.polkadot-rust.soramitsu.co.jp:443")!
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let operation = JSONRPCListOperation<RuntimeVersion>(engine: engine,
                                                             method: "chain_getRuntimeVersion",
                                                             parameters: [])

        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            logger.debug("Received response: \(result)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMultipleChangesQuery() throws {
        try performTestMultipleChangesQuery(keysCount: 100)
        try performTestMultipleChangesQuery(keysCount: 1000)
        try performTestMultipleChangesQuery(keysCount: 1999)
        try performTestMultipleChangesQuery(keysCount: 3000)
        try performTestMultipleChangesQuery(keysCount: 3001)
        try performTestMultipleChangesQuery(keysCount: 1001)
        try performTestMultipleChangesQuery(keysCount: 0)
    }

    func performTestMultipleChangesQuery(keysCount: Int) throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let chain = Chain.kusama
        let storageFacade = SubstrateStorageTestFacade()

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            networkType: chain,
                                                            keychain: keychain,
                                                            settings: settings)

        let operationManager = OperationManagerFacade.sharedManager

        let runtimeService = try createRuntimeService(from: storageFacade,
                                                      operationManager: operationManager,
                                                      chain: chain)

        runtimeService.setup()

        let webSocketService = createWebSocketService(storageFacade: storageFacade,
                                                      settings: settings)
        webSocketService.setup()

        let address = "GqpApQStgzzGxYa1XQZQUq9L3aXhukxDWABccbeHEh7zPYR"

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let accountId = try SS58AddressFactory().accountId(from: address)

        let keyParams1: () throws -> [StringScaleMapper<EraIndex>] = {
            (0..<EraIndex(keysCount)).map { StringScaleMapper(value: $0) }
        }

        let keyParams2: () throws -> [AccountId] = {
            (0..<keysCount).map { _ in accountId }
        }

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let factoryClosure: () throws -> RuntimeCoderFactoryProtocol = {
            try coderFactoryOperation.extractNoCancellableResultData()
        }

        // when

        let wrapper: CompoundOperationWrapper<[StorageResponse<ValidatorExposure>]> = storageRequestFactory.queryItems(
            engine: webSocketService.connection!,
            keyParams1: keyParams1,
            keyParams2: keyParams2,
            factory: factoryClosure,
            storagePath: .erasStakers
        )

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        OperationQueue().addOperations(
            [coderFactoryOperation] + wrapper.allOperations,
            waitUntilFinished: true
        )

        let resultsCount = try wrapper.targetOperation.extractNoCancellableResultData().count

        // then

        XCTAssertEqual(keysCount, resultsCount)
    }

    private func createRuntimeService(from storageFacade: StorageFacadeProtocol,
                                      operationManager: OperationManagerProtocol,
                                      chain: Chain,
                                      logger: LoggerProtocol? = nil) throws
    -> RuntimeRegistryService {
        let providerFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                           operationManager: operationManager,
                                                           logger: logger)

        let topDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ??
            FileManager.default.temporaryDirectory
        let runtimeDirectory = topDirectory.appendingPathComponent("runtime").path
        let filesRepository = RuntimeFilesOperationFacade(repository: FileRepository(),
                                                          directoryPath: runtimeDirectory)

        return RuntimeRegistryService(chain: chain,
                                      metadataProviderFactory: providerFactory,
                                      dataOperationFactory: DataOperationFactory(),
                                      filesOperationFacade: filesRepository,
                                      operationManager: operationManager,
                                      eventCenter: EventCenter.shared,
                                      logger: logger)
    }

    private func createWebSocketService(storageFacade: StorageFacadeProtocol,
                                        settings: SettingsManagerProtocol) -> WebSocketServiceProtocol {
        let connectionItem = settings.selectedConnection
        let address = settings.selectedAccount?.address

        let settings = WebSocketServiceSettings(url: connectionItem.url,
                                                addressType: connectionItem.type,
                                                address: address)
        let factory = WebSocketSubscriptionFactory(storageFacade: storageFacade)
        return WebSocketService(settings: settings,
                                connectionFactory: WebSocketEngineFactory(),
                                subscriptionsFactory: factory,
                                applicationHandler: ApplicationHandler())
    }
}
