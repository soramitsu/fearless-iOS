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

    func testWestendStakersFetch() throws {
        // given

        let chainId = Chain.westend.genesisHash
        let storageFacade = SubstrateStorageTestFacade()

        let operationManager = OperationManagerFacade.sharedManager

        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let connection = chainRegistry.getConnection(for: chainId)!
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let hexKeys: [String] = ["0x5f3e4907f716ac89b6347d15ececedca8bde0a0ea8864605e3b68ed9cb2da01b69ce245bbdafd3b0150f000003adc196911e491e08264834504a64ace1373f0c8ed5d57381ddf54a2f67a318fa42b1352681606d", "0x5f3e4907f716ac89b6347d15ececedca8bde0a0ea8864605e3b68ed9cb2da01b69ce245bbdafd3b0150f00000b1caab63c52abf8bc92ae6f12477a9c52d97b17bf3cf98158c081c69f8010d08f25b2dfce727940", "0x5f3e4907f716ac89b6347d15ececedca8bde0a0ea8864605e3b68ed9cb2da01b69ce245bbdafd3b0150f000016d5103a6adeae4fc21ad1e5198cc0dc3b0f9f43a50f292678f63235ea321e59385d7ee45a720836", "0x5f3e4907f716ac89b6347d15ececedca8bde0a0ea8864605e3b68ed9cb2da01b69ce245bbdafd3b0150f00002726099619673eb6a0bcc553cb33f8b4676e6b6e812cafd86ea962dd99e5c765663a0a673e43704e", "0x5f3e4907f716ac89b6347d15ececedca8bde0a0ea8864605e3b68ed9cb2da01b69ce245bbdafd3b0150f00004245138345ca3fd8aebb0211dbb07b4d335a657257b8ac5e53794c901e4f616d4a254f2490c43934", "0x5f3e4907f716ac89b6347d15ececedca8bde0a0ea8864605e3b68ed9cb2da01b69ce245bbdafd3b0150f00004f0f0dc89f14ad14767f36484b1e2acf5c265c7a64bfb46e95259c66a8189bbcd216195def436852", "0x5f3e4907f716ac89b6347d15ececedca8bde0a0ea8864605e3b68ed9cb2da01b69ce245bbdafd3b0150f00005c69b53821debaa39ae581fef1fc06828723715731adcf810e42ce4dadad629b1b7fa5c3c144a81d", "0x5f3e4907f716ac89b6347d15ececedca8bde0a0ea8864605e3b68ed9cb2da01b69ce245bbdafd3b0150f0000ce6a96a3775ab416f268995cc38974ce0686df1364875f26f2c32b246ddc18835512c3f9969f5836"]

        let keys: () throws -> [Data] = {
            return try hexKeys.map { try Data(hexString: $0) }
        }

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let factoryClosure: () throws -> RuntimeCoderFactoryProtocol = {
            try coderFactoryOperation.extractNoCancellableResultData()
        }

        // when

        let wrapper: CompoundOperationWrapper<[StorageResponse<ValidatorExposure>]> = storageRequestFactory.queryItems(
            engine: connection,
            keys: keys,
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

        XCTAssertEqual(hexKeys.count, resultsCount)
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

        let chainId = Chain.kusama.genesisHash
        let storageFacade = SubstrateStorageTestFacade()

        let operationManager = OperationManager()

        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        let connection = chainRegistry.getConnection(for: chainId)!
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!

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
            engine: connection,
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
}
