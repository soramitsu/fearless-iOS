import XCTest
import SSFUtils
import SSFModels
import SSFRuntimeCodingService
import BigInt
import IrohaCrypto
import RobinHood
@testable import fearless

final class AssetHubBuilderBoundaryTests: XCTestCase {
    private struct Calls: Codable { let calls: [JSON] }

    func testLargeAtomicBatchHashesExactMetadataEncodedPayloadAndRawCallMatches() throws {
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        let factory = SubstrateCallFactoryDefault(runtimeService: runtime)
        let builder = try AssetHubExtrinsicBuilder(factory: runtime.factory, genesisHash: runtime.chainId).with(nonce: 34)
        let calls = (0 ..< 100).map { _ in factory.unbond(amount: 12345) }
        for call in calls { _ = try builder.adding(call: call) }
        let jsonCalls = try calls.map { try $0.toScaleCompatibleJSON() }
        let batch = RuntimeCall(moduleName: "Utility", callName: "batch_all", args: Calls(calls: jsonCalls))
        let encoder = runtime.factory.createEncoder()
        try encoder.append(json: batch.toScaleCompatibleJSON(), type: GenericType.call.name)
        let encodedCall = try encoder.encode()
        let genesis = try Data(hexStringSSF: runtime.chainId)
        let extensions = try AssetHubSignedExtensions(factory: runtime.factory, genesis: genesis, block: genesis, era: .immortal, nonce: 34, tip: 0).encode()
        let payload = encodedCall + extensions.extra + extensions.additional
        XCTAssertGreaterThan(payload.count, 256)
        XCTAssertEqual(try builder.buildSignature(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata), try payload.blake2b32())
        let raw = try AssetHubExtrinsicBuilder(factory: runtime.factory, genesisHash: runtime.chainId).with(nonce: 34).adding(rawCall: encodedCall)
        XCTAssertEqual(try raw.buildSignature(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata), try payload.blake2b32())
        XCTAssertThrowsError(try raw.adding(rawCall: encodedCall + Data([0])))
        XCTAssertThrowsError(try raw.adding(rawCall: Data([255])))
        _ = builder.with(shouldUseAtomicBatch: false)
        XCTAssertNotEqual(try builder.buildSignature(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata), try payload.blake2b32())
    }

    func testDummyFeeSignaturesUseEachNativeCryptoVariantAndRejectMalformedLengths() throws {
        let runtime = try AssetHubRuntimeFixture(name: "westend")
        let factory = SubstrateCallFactoryDefault(runtimeService: runtime)
        for (type, count) in [(CryptoType.ed25519, 64), (.sr25519, 64), (.ecdsa, 65)] {
            let builder = try AssetHubExtrinsicBuilder(factory: runtime.factory, genesisHash: runtime.chainId)
                .with(address: MultiAddress.accoundId(Data(repeating: 1, count: 32))).with(nonce: 0).adding(call: factory.chill())
            _ = try builder.signing(by: { _ in Data(repeating: 0, count: count) }, of: type, using: runtime.factory.createEncoder(), metadata: runtime.factory.metadata)
            XCTAssertFalse(try builder.build(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata).isEmpty)
            XCTAssertThrowsError(try builder.signing(by: { _ in Data(repeating: 0, count: count - 1) }, of: type, using: runtime.factory.createEncoder(), metadata: runtime.factory.metadata))
        }
    }

    func testSignerCannotMutatePayloadBeforeSignatureIsAttached() throws {
        let runtime = try AssetHubRuntimeFixture(name: "kusama")
        let builder = try AssetHubExtrinsicBuilder(factory: runtime.factory, genesisHash: runtime.chainId)
            .with(address: MultiAddress.accoundId(Data(repeating: 1, count: 32))).with(nonce: 0)
            .adding(call: SubstrateCallFactoryDefault(runtimeService: runtime).chill())
        XCTAssertThrowsError(try builder.signing(by: { _ in
            _ = builder.with(tip: 123)
            return Data(repeating: 0, count: 64)
        }, of: .ed25519, using: runtime.factory.createEncoder(), metadata: runtime.factory.metadata)) { error in
            guard case AssetHubExtrinsicBuilderError.payloadChangedDuringSigning = error else { return XCTFail("Unexpected \(error)") }
        }
        let bytes = try builder.build(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata)
        let decoder = try ScaleDecoder(data: bytes)
        _ = try BigUInt(scaleDecoder: decoder)
        XCTAssertEqual(try UInt8(scaleDecoder: decoder), 4)
    }
}

/// Staking extrinsics on an Asset Hub are signed against the genesis hash compiled into the route, whatever a node says.
final class AssetHubExtrinsicGenesisTests: XCTestCase {
    func testAssetHubSignsAgainstRouteGenesisWithoutAskingTheNode() throws {
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        let engine = GenesisEngine(blockZero: runtime.chainId)
        let factory = makeFactory(runtime: runtime, engine: engine)

        let genesis = try AssetHubTestSupport.execute(CompoundOperationWrapper(targetOperation: factory.createGenesisBlockHashOperation()))
        XCTAssertEqual(genesis, runtime.chainId)
        XCTAssertTrue(engine.methods.isEmpty, "No node is asked for the genesis hash")

        let signer = RecordingSigner()
        let call = SubstrateCallFactoryDefault(runtimeService: runtime).chill()
        let hash = try AssetHubTestSupport.execute(factory.submit({ try $0.adding(call: call) }, signer: signer))
        XCTAssertEqual(hash, "0x01")
        let expected = try AssetHubExtrinsicBuilder(factory: runtime.factory, genesisHash: runtime.chainId)
            .with(nonce: 7)
            .with(era: .immortal, blockHash: runtime.chainId)
            .adding(call: call)
            .buildSignature(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata)
        XCTAssertEqual(signer.payloads, [expected])
    }

    func testImmortalSigningRefusesANodeWhoseBlockZeroIsAnotherNetwork() throws {
        let runtime = try AssetHubRuntimeFixture(name: "kusama")
        let engine = GenesisEngine(blockZero: Data(repeating: 9, count: 32).toHex())
        let signer = RecordingSigner()
        let call = SubstrateCallFactoryDefault(runtimeService: runtime).chill()
        XCTAssertThrowsError(try AssetHubTestSupport.execute(
            makeFactory(runtime: runtime, engine: engine).submit({ try $0.adding(call: call) }, signer: signer)
        ))
        XCTAssertTrue(signer.payloads.isEmpty)
    }

    /// A mortal signature asked for by a node of another network is still bound to the hub's genesis, so it is not valid
    /// there; the node is never asked for block zero.
    func testMortalSignatureFromAnyNodeIsBoundToTheRouteGenesis() throws {
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        let checkpoint = Data(repeating: 7, count: 32).toHex()
        let engine = GenesisEngine(blockZero: Data(repeating: 9, count: 32).toHex(), blockHash: checkpoint)
        let factory = ExtrinsicOperationFactory(
            accountId: AssetHubTestSupport.nominator,
            chainFormat: .substrate(0),
            cryptoType: .sr25519,
            runtimeRegistry: runtime,
            engine: engine,
            eraOperationFactory: FixedEraFactory(parameters: ExtrinsicEraParameters(
                blockNumber: 100, extrinsicEra: .mortal(period: 64, phase: 36)
            ))
        )
        let signer = RecordingSigner()
        let call = SubstrateCallFactoryDefault(runtimeService: runtime).chill()

        _ = try AssetHubTestSupport.execute(factory.submit({ try $0.adding(call: call) }, signer: signer))

        let expected = try AssetHubExtrinsicBuilder(factory: runtime.factory, genesisHash: runtime.chainId)
            .with(nonce: 7)
            .with(era: .mortal(period: 64, phase: 36), blockHash: checkpoint)
            .adding(call: call)
            .buildSignature(encodingBy: runtime.factory.createEncoder(), metadata: runtime.factory.metadata)
        XCTAssertEqual(signer.payloads, [expected])
        let genesis = try Data(hexStringSSF: runtime.chainId)
        XCTAssertNotNil(expected.range(of: genesis), "The signed payload carries the hub genesis")
        XCTAssertNil(expected.range(of: Data(repeating: 9, count: 32)), "The node's block zero is not signed")
        XCTAssertEqual(engine.blockHashParameters, ["0x00000064"], "Only the mortality checkpoint is asked for")
    }

    func testPinnedGenesisThatIsNotTheRouteIsRefusedBeforeSigning() throws {
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        let engine = GenesisEngine(blockZero: runtime.chainId)
        let other = AssetHubStakingRoute.routes[1].stakingChainId
        let factory = makeFactory(runtime: runtime, engine: engine, pinned: other)
        let signer = RecordingSigner()
        let call = SubstrateCallFactoryDefault(runtimeService: runtime).chill()
        XCTAssertThrowsError(try AssetHubTestSupport.execute(factory.submit({ try $0.adding(call: call) }, signer: signer))) { error in
            guard case ChainRegistryError.chainUnavailable = error else { return XCTFail("Unexpected \(error)") }
        }
        XCTAssertTrue(signer.payloads.isEmpty)
    }

    func testRuntimeOutsideTheRoutesStillAsksTheNodeForItsGenesis() throws {
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        let engine = GenesisEngine(blockZero: runtime.chainId)
        let factory = ExtrinsicOperationFactory(
            accountId: AssetHubTestSupport.nominator,
            chainFormat: .substrate(0),
            cryptoType: .sr25519,
            runtimeRegistry: RuntimeCodingServiceStub(factory: runtime.factory),
            engine: engine,
            eraOperationFactory: ImmortalEraOperationFactory()
        )
        _ = try AssetHubTestSupport.execute(CompoundOperationWrapper(targetOperation: factory.createGenesisBlockHashOperation()))
        XCTAssertEqual(engine.methods, ["chain_getBlockHash"])
    }

    private func makeFactory(
        runtime: AssetHubRuntimeFixture,
        engine: GenesisEngine,
        pinned: String? = nil
    ) -> ExtrinsicOperationFactory {
        ExtrinsicOperationFactory(
            accountId: AssetHubTestSupport.nominator,
            chainFormat: .substrate(0),
            cryptoType: .sr25519,
            runtimeRegistry: runtime,
            engine: engine,
            pinnedGenesisHash: pinned,
            eraOperationFactory: ImmortalEraOperationFactory()
        )
    }

    private struct FixedEraFactory: ExtrinsicEraOperationFactoryProtocol {
        let parameters: ExtrinsicEraParameters

        func createOperation(
            from _: JSONRPCEngine,
            runtimeService _: RuntimeCodingServiceProtocol
        ) -> CompoundOperationWrapper<ExtrinsicEraParameters> {
            CompoundOperationWrapper.createWithResult(parameters)
        }
    }

    private final class RecordingSigner: SigningWrapperProtocol {
        private(set) var payloads: [Data] = []

        func sign(_ originalData: Data) throws -> IRSignatureProtocol {
            payloads.append(originalData)
            return try DummySigner(cryptoType: .sr25519).sign(originalData)
        }
    }

    /// Answers nonce, block hash and submission; records the methods it was asked.
    private final class GenesisEngine: JSONRPCEngine {
        let blockZero: String
        let blockHash: String?
        private let lock = NSLock()
        private var recorded: [String] = []
        private var heights: [String] = []
        private var identifier: UInt16 = 0
        var connectionName: String?
        var url: URL?
        var pendingEngineRequests: [JSONRPCRequest] { [] }

        var methods: [String] {
            lock.lock(); defer { lock.unlock() }
            return recorded
        }

        var blockHashParameters: [String] {
            lock.lock(); defer { lock.unlock() }
            return heights
        }

        init(blockZero: String, blockHash: String? = nil) {
            self.blockZero = blockZero
            self.blockHash = blockHash
        }

        func callMethod<P: Codable, T: Decodable>(
            _ method: String,
            params: P?,
            options _: JSONRPCOptions,
            completion closure: ((Result<T, Error>) -> Void)?
        ) throws -> UInt16 {
            let requestId = generateRequestId()
            let parameters = try params.map {
                try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) as? [Any] ?? []
            } ?? []
            lock.lock(); recorded.append(method); lock.unlock()
            let answer: Any
            switch method {
            case RPCMethod.getExtrinsicNonce: answer = 7
            case RPCMethod.getBlockHash:
                let height = parameters.first as? String ?? ""
                lock.lock(); heights.append(height); lock.unlock()
                let isBlockZero = UInt64(height.replacingOccurrences(of: "0x", with: ""), radix: 16) == 0
                let hash = isBlockZero ? blockZero : (blockHash ?? blockZero)
                answer = hash.hasPrefix("0x") ? hash : "0x" + hash
            case RPCMethod.submitExtrinsic: answer = "0x01"
            default:
                closure?(.failure(NSError(domain: "unexpected \(method)", code: 1)))
                return requestId
            }
            do {
                let data = try JSONSerialization.data(withJSONObject: answer, options: .fragmentsAllowed)
                closure?(.success(try JSONDecoder().decode(T.self, from: data)))
            } catch {
                closure?(.failure(error))
            }
            return requestId
        }

        func subscribe<P: Codable, T: Decodable>(
            _: String,
            params _: P?,
            updateClosure _: @escaping (T) -> Void,
            failureClosure _: @escaping (Error, Bool) -> Void
        ) throws -> UInt16 {
            throw NSError(domain: "unexpected subscription", code: 1)
        }

        func generateRequestId() -> UInt16 {
            lock.lock(); defer { lock.unlock() }
            identifier &+= 1
            return identifier
        }

        func cancelForIdentifier(_: UInt16) {}
        func addSubscription(_: JSONRPCSubscribing) {}
        func reconnect(url: URL) { self.url = url }
        func connectIfNeeded() {}
        func disconnectIfNeeded() {}
        func unsubsribe(_: UInt16) throws {}
    }
}
