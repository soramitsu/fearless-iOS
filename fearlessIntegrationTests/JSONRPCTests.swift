import XCTest
@testable import fearless
import FearlessUtils
import RobinHood
import IrohaCrypto
import BigInt
import xxHash_Swift

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

    func testGetPendingTransactions() {
        // given

        let url = URL(string: "wss://westend-rpc.polkadot.io/")!
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let operation = JSONRPCListOperation<[String]>(engine: engine,
                                                       method: "author_pendingExtrinsics",
                                                       parameters: [])

        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            for extrinsicHex in result {
                guard let extrisicData = try? Data(hexString: extrinsicHex) else {
                    continue
                }

                guard
                    let decoder = try? ScaleDecoder(data: extrisicData),
                    let extrinsic = try? Extrinsic(scaleDecoder: decoder) else {
                    continue
                }

                logger.debug("Did receive: \(extrinsic)")
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTransfer() throws {
        do {
            let operationQueue = OperationQueue()

            let url = URL(string: "wss://westend-rpc.polkadot.io/")!
            let engine = WebSocketEngine(url: url, logger: Logger.shared)

            let privateKeyData = try Data(hexString: "f3923eea431177cd21906d4308aea61c037055fb00575cae687217c6d8b2397f")

            let accountId = try Data(hexString: "fdc41550fb5186d71cae699c31731b3e1baa10680c7bd6b3831a6d222cf4d168")

            let privateKey = try EDPrivateKey(rawData: privateKeyData)

            let extrinsicData = try generateExtrinsicToAccount("5CDayXd3cDCWpBkSXVsVfhE5bWKyTZdD3D1XUinR1ezS1sGn",
                                                               from: accountId,
                                                               amount: Decimal(0.21)
                                                                .toSubstrateAmount(precision: 12)!,
                                                               nonce: 0,
                                                               privateKey: privateKey)
            let operation = JSONRPCListOperation<RuntimeDispatchInfo>(engine: engine,
                                                                      method: "author_submitExtrinsic",
                                                                      parameters: [extrinsicData.toHex(includePrefix: true)])

            operationQueue.addOperations([operation], waitUntilFinished: true)

            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            Logger.shared.debug("Received response: \(result)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

    }

    func testGetPaymentInfo() throws {
        // given

        let seed = Data(repeating: 0, count: 32)
        let keypair = try SNKeyFactory().createKeypair(fromSeed: seed)
        let logger = Logger.shared
        let addressFactory = SS58AddressFactory()
        let publicKey = try Data(hexString: "fdc41550fb5186d71cae699c31731b3e1baa10680c7bd6b3831a6d222cf4d168")
        let address = try addressFactory.address(fromPublicKey: try EDPublicKey(rawData: publicKey),
                                                 type: .genericSubstrate)

        logger.debug("Transfer from: \(address)")

        let operationQueue = OperationQueue()

        let url = URL(string: "wss://westend-rpc.polkadot.io/")!
        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        guard let amount = Decimal(string: "1.01")?.toSubstrateAmount(precision: 12) else {
            XCTFail("Unexpected nil amount")
            return
        }

        let extrinsicData = try generateExtrinsicToAccount("5CDayXd3cDCWpBkSXVsVfhE5bWKyTZdD3D1XUinR1ezS1sGn",
                                                           amount: amount,
                                                           nonce: 6,
                                                           keypair: keypair)

        Logger.shared.debug("Extrinsic: \(extrinsicData.toHex())")

        let operation = JSONRPCListOperation<RuntimeDispatchInfo>(engine: engine,
                                                                  method: "payment_queryInfo",
                                                                  parameters: [extrinsicData.toHex(includePrefix: true)])

        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            logger.debug("Received response: \(result)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: Private

    func generateExtrinsicToAccount(_ address: String,
                                    amount: BigUInt,
                                    nonce: UInt32,
                                    keypair: SNKeypairProtocol) throws -> Data {
        let genesisHash = try Data(hexString: "0xe143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e")

        let addressFactory = SS58AddressFactory()
        let receiverAccountId = try addressFactory.accountId(fromAddress: address,
                                                             type: .genericSubstrate)
        let transferCall = TransferCallV27(receiver: receiverAccountId,
                                           amount: amount)

        let callEncoder = ScaleEncoder()
        try transferCall.encode(scaleEncoder: callEncoder)
        let callArguments = callEncoder.encode()

        let call = Call(moduleIndex: 4, callIndex: 0, arguments: callArguments)

        let era = Era.immortal
        let tip = BigUInt(0)

        let payload = ExtrinsicPayload(call: call,
                                       era: era,
                                       nonce: nonce,
                                       tip: tip,
                                       specVersion: 44,
                                       transactionVersion: 3,
                                       genesisHash: genesisHash,
                                       blockHash: genesisHash)

        let payloadEncoder = ScaleEncoder()
        try payload.encode(scaleEncoder: payloadEncoder)

        let signer = SNSigner(keypair: keypair)
        let signature = try signer.sign(payloadEncoder.encode())

        let transaction = TransactionV27(accountId: receiverAccountId,
                                         signatureVersion: 0,
                                         signature: signature.rawData(),
                                         era: era,
                                         nonce: nonce,
                                         tip: tip)

        let extrinsic = ExtrinsicV27(version: 132,
                                     transaction: transaction,
                                     call: call)

        let extrinsicCoder = ScaleEncoder()
        try extrinsic.encode(scaleEncoder: extrinsicCoder)

        return extrinsicCoder.encode()
    }

    func generateExtrinsicToAccount(_ address: String,
                                    from accountId: Data,
                                    amount: BigUInt,
                                    nonce: UInt32,
                                    privateKey: EDPrivateKey) throws -> Data {
        let genesisHash = try Data(hexString: "0xe143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e")

        let addressFactory = SS58AddressFactory()
        let receiverAccountId = try addressFactory.accountId(fromAddress: address,
                                                             type: .genericSubstrate)
        let transferCall = TransferCallV27(receiver: receiverAccountId,
                                           amount: amount)

        let callEncoder = ScaleEncoder()
        try transferCall.encode(scaleEncoder: callEncoder)
        let callArguments = callEncoder.encode()

        let call = Call(moduleIndex: 4, callIndex: 0, arguments: callArguments)

        let era = Era.immortal
        let tip = BigUInt(0)

        let payload = ExtrinsicPayload(call: call,
                                       era: era,
                                       nonce: nonce,
                                       tip: tip,
                                       specVersion: 44,
                                       transactionVersion: 3,
                                       genesisHash: genesisHash,
                                       blockHash: genesisHash)

        let payloadEncoder = ScaleEncoder()
        try payload.encode(scaleEncoder: payloadEncoder)

        let signer = EDSigner(privateKey: privateKey)
        let signature = try signer.sign(payloadEncoder.encode())

        let transaction = TransactionV27(accountId: accountId,
                                         signatureVersion: 0,
                                         signature: signature.rawData(),
                                         era: era,
                                         nonce: nonce,
                                         tip: tip)

        let extrinsic = ExtrinsicV27(version: 132,
                                     transaction: transaction,
                                     call: call)

        let extrinsicCoder = ScaleEncoder()
        try extrinsic.encode(scaleEncoder: extrinsicCoder)

        return extrinsicCoder.encode()
    }
}
