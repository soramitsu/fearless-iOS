import Foundation
import XCTest
import SSFUtils
import SSFRuntimeCodingService
import BigInt
@testable import fearless

final class AssetHubStorageFixture: JSONRPCEngine {
    private struct SlashKey: Encodable {
        let account: Data
        let page: UInt32
        func encode(to encoder: Encoder) throws {
            var values = encoder.unkeyedContainer()
            try values.encode(account)
            try values.encode(fearless.StringScaleMapper(value: UInt32(1)))
            try values.encode(fearless.StringScaleMapper(value: page))
        }
    }

    let runtime: AssetHubRuntimeFixture
    let block = Data(repeating: 0x42, count: 32)
    var values: [String: String] = [:]
    private let requestLock = NSLock()
    private var recordedRequests: [(String, [Any])] = []
    var requests: [(String, [Any])] {
        requestLock.lock(); defer { requestLock.unlock() }
        return recordedRequests
    }

    var maximumPage = 1
    var repeatPage = false
    var omitResponse = false
    var allowsUnpinnedReads = false
    var error: Error?
    var metadataResponse: String?
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }
    private var identifier: UInt16 = 0

    init(name: String = "polkadot") throws { runtime = try AssetHubRuntimeFixture(name: name) }

    func put(_ path: fearless.StorageCodingPath, json: String, era: UInt32? = nil, account: Data? = nil, page: UInt32? = nil) throws -> Data {
        let key: Data
        if era != nil || account != nil {
            var components: [[NMapKeyParamProtocol]] = []
            if let era = era { components.append([NMapKeyParam(value: fearless.StringScaleMapper(value: era))]) }
            if path == .unappliedSlashes, let account = account, let page = page {
                components.append([NMapKeyParam(value: SlashKey(account: account, page: page))])
            } else {
                if let account = account { components.append([NMapKeyParam(value: account)]) }
                if let page = page { components.append([NMapKeyParam(value: fearless.StringScaleMapper(value: page))]) }
            }
            key = try XCTUnwrap(NMapKeyEncodingWorker(codingFactory: runtime.factory, path: path, storageKeyFactory: StorageKeyFactory(), keyParams: [components]).performEncoding().first)
        } else {
            key = try StorageKeyFactory().key(from: path)
        }
        let metadata = try XCTUnwrap(runtime.factory.metadata.getStorageMetadata(for: path))
        let type = try metadata.type.typeName(using: runtime.factory.metadata.schemaResolver)
        let encoder = runtime.factory.createEncoder()
        let raw = try JSONSerialization.jsonObject(with: Data(json.utf8), options: .fragmentsAllowed)
        let compatible = try JSONSerialization.data(withJSONObject: scaleCompatible(raw), options: .fragmentsAllowed)
        try encoder.append(json: JSONDecoder().decode(JSON.self, from: compatible), type: type)
        values[key.toHex(includePrefix: true)] = try encoder.encode().toHex(includePrefix: true)
        return key
    }

    private func scaleCompatible(_ value: Any) -> Any {
        if let string = value as? String, string.hasPrefix("0x"), let bytes = try? Data(hexStringSSF: string), bytes.count == 32 {
            return bytes.map { String($0) }
        }
        if let values = value as? [Any] { return values.map(scaleCompatible) }
        if let values = value as? [String: Any] { return values.mapValues(scaleCompatible) }
        return value
    }

    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options _: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 {
        let identifier = generateRequestId()
        do {
            if let error = error { throw error }
            let parameters = try params.map { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) as? [Any] ?? [] } ?? []
            requestLock.lock()
            recordedRequests.append((method, parameters))
            requestLock.unlock()
            let object: Any
            switch method {
            case RPCMethod.getRuntimeMetadata: object = try XCTUnwrap(metadataResponse)
            case RPCMethod.getFinalizedBlockHash: object = block.toHex(includePrefix: true)
            case "state_getKeysPaged":
                let prefix = try XCTUnwrap(parameters.first as? String)
                XCTAssertEqual(parameters.last as? String, block.toHex(includePrefix: true))
                let start = repeatPage ? nil : parameters[2] as? String
                // The explicit cursor predicate below avoids treating a short page as exhaustion.
                let selected = values.keys.filter { key in key.hasPrefix(prefix) && (start.map { key > $0 } ?? true) }.sorted()
                let response = Array(selected.prefix(maximumPage))
                closure?(.success(try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: response))))
                return identifier
            case RPCMethod.queryStorageAt:
                let keys = try XCTUnwrap(parameters.first as? [String])
                if !allowsUnpinnedReads { XCTAssertEqual(parameters.last as? String, block.toHex(includePrefix: true)) }
                let changes: [[Any]] = (omitResponse ? [] : keys).map { [$0, values[$0] as Any? ?? NSNull()] }
                object = [["block": block.toHex(includePrefix: true), "changes": changes]]
            default: throw fearless.ConvenienceError(error: "Unexpected RPC \(method)")
            }
            let data = try JSONSerialization.data(withJSONObject: object, options: .fragmentsAllowed)
            closure?(.success(try JSONDecoder().decode(T.self, from: data)))
        } catch { closure?(.failure(error)) }
        return identifier
    }

    func subscribe<P: Codable, T: Decodable>(_: String, params _: P?, updateClosure _: @escaping (T) -> Void, failureClosure _: @escaping (Error, Bool) -> Void) throws -> UInt16 { throw fearless.ConvenienceError(error: "Unexpected subscription") }
    func generateRequestId() -> UInt16 {
        requestLock.lock(); defer { requestLock.unlock() }
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
