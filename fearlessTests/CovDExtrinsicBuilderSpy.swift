import BigInt
import Foundation
import SSFModels
import SSFUtils

/// Records the runtime calls a builder closure adds, so tests can assert module and call names.
final class CovDExtrinsicBuilderSpy: ExtrinsicBuilderProtocol {
    private(set) var calls: [(module: String, call: String, args: Data)] = []
    private(set) var usesAtomicBatch = false

    func with<A: Codable>(address _: A) throws -> Self { self }
    func with(nonce _: UInt32) -> Self { self }
    func with(era _: Era, blockHash _: String) -> Self { self }
    func with(tip _: BigUInt) -> Self { self }
    func with(appId _: BigUInt) -> Self { self }

    func with(shouldUseAtomicBatch: Bool) -> Self {
        usesAtomicBatch = shouldUseAtomicBatch
        return self
    }

    func adding<T: RuntimeCallable>(call: T) throws -> Self {
        calls.append((call.moduleName, call.callName, try JSONEncoder().encode(call.args)))
        return self
    }

    func adding(rawCall _: Data) throws -> Self { self }

    func signing(
        by _: (Data) throws -> Data,
        of _: SSFModels.CryptoType,
        using _: DynamicScaleEncoding,
        metadata _: RuntimeMetadata
    ) throws -> Self { self }

    func build(encodingBy _: DynamicScaleEncoding, metadata _: RuntimeMetadata) throws -> Data { Data() }

    func buildSignature(encodingBy _: DynamicScaleEncoding, metadata _: RuntimeMetadata) throws -> Data { Data() }

    func argsObject(at index: Int) -> [String: Any]? {
        guard calls.indices.contains(index) else { return nil }
        return (try? JSONSerialization.jsonObject(with: calls[index].args)) as? [String: Any]
    }
}
