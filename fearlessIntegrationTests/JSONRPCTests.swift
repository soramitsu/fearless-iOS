import XCTest
@testable import fearless
import FearlessUtils
import RobinHood
import IrohaCrypto
import BigInt

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

        let operation = JSONRPCOperation<RpcInterface>(engine: engine,
                                                       method: "rpc_methods",
                                                       parameters: [])

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

        let operation = JSONRPCOperation<String?>(engine: engine,
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

        let operation = JSONRPCOperation<String>(engine: engine,
                                                 method: "system_chain",
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

    func testGetRuntimeVersion() {
        // given

        let url = URL(string: "wss://ws.validator.dev.polkadot-rust.soramitsu.co.jp:443")!
        let logger = Logger.shared
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let operation = JSONRPCOperation<RuntimeVersion>(engine: engine,
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

        let operation = JSONRPCOperation<[String]>(engine: engine,
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

    func testGetPaymentInfo() throws {
        // given

        let seed = Data(repeating: 0, count: 32)
        let keypair = try SNKeyFactory().createKeypair(fromSeed: seed)
        let logger = Logger.shared
        let addressFactory = SS58AddressFactory()
        let address = try addressFactory.address(fromPublicKey: keypair.publicKey(),
                                                 type: .genericSubstrate)

        logger.debug("Transfer from: \(address)")

        let operationQueue = OperationQueue()

        let url = URL(string: "wss://ws.validator.dev.polkadot-rust.soramitsu.co.jp:443")!
        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let extrinsicData = try generateExtrinsicToAccount("5FCj3BzHo5274Jwd6PFdsGzSgDtQ724k7o7GRYTzAf7n37vk",
                                                           amount: Decimal(10).toSubstrateAmount()!,
                                                           nonce: 0,
                                                           keypair: keypair)

        Logger.shared.debug("Extrinsic: \(extrinsicData.toHex())")

        let operation = JSONRPCOperation<RuntimeDispatchInfo>(engine: engine,
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
        let transferCall = TransferCall(receiver: receiverAccountId,
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
                                       specVersion: 37,
                                       transactionVersion: 2,
                                       genesisHash: genesisHash,
                                       blockHash: genesisHash)

        let payloadEncoder = ScaleEncoder()
        try payload.encode(scaleEncoder: payloadEncoder)

        let signer = SNSigner(keypair: keypair)
        let signature = try signer.sign(payloadEncoder.encode())

        let transaction = Transaction(accountId: receiverAccountId,
                                      signatureVersion: 1,
                                      signature: signature.rawData(),
                                      era: era,
                                      nonce: nonce,
                                      tip: tip)

        let extrinsic = Extrinsic(version: 132,
                                  transaction: transaction,
                                  call: call)

        let extrinsicCoder = ScaleEncoder()
        try extrinsic.encode(scaleEncoder: extrinsicCoder)

        return extrinsicCoder.encode()
    }
}
