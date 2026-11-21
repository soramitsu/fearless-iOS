import RobinHood
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

final class CovFStorageServicesTests: XCTestCase {
    func testPagedQueryAccumulatesPagesAndPassesLastKeyAsOffset() throws {
        let engine = CovFQueryEngine()
        engine.replies = [["0x01", "0x02"], ["0x03"]]
        let service = query(engine)
        let done = expectation(description: "pages")
        var values: [Data] = []
        service.start {
            do { values = try $0.get() } catch { XCTFail("\(error)") }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(values, [Data([1]), Data([2]), Data([3])])
        XCTAssertEqual(engine.methods, [RPCMethod.getStorageKeysPaged, RPCMethod.getStorageKeysPaged])
        XCTAssertEqual(engine.parameters.count, 2)
        let first = try XCTUnwrap(engine.parameters.first as? [Any])
        let second = try XCTUnwrap(engine.parameters.last as? [Any])
        XCTAssertEqual(first.first as? String, "0xaa")
        XCTAssertEqual(first[1] as? Int, 2)
        XCTAssertEqual(second.last as? String, "0x02")
        var restartError: Error?
        service.start { restartError = covFFailure($0) }
        XCTAssertTrue(restartError is StorageKeysQueryService<Data>.InternalError)
        service.cancel()
        XCTAssertEqual(engine.methods.count, 2)
    }

    func testPagedQueryReturnsErrorsForInvalidHexTransportAndPrefix() throws {
        for kind in 0 ..< 3 {
            let engine = CovFQueryEngine()
            engine.replies = [["not-hex"]]
            if kind == 1 { engine.failure = NSError(domain: "query", code: 7) }
            let service = query(engine, prefix: { if kind == 2 { throw NSError(domain: "prefix", code: 9) }; return Data([0xaa]) })
            let done = expectation(description: "error \(kind)")
            service.start { result in
                XCTAssertNotNil(covFFailure(result))
                done.fulfill()
            }
            wait(for: [done], timeout: 5)
            XCTAssertEqual(engine.methods.count, kind == 2 ? 0 : 1)
        }
    }

    func testCancelWhileQueuedDeliversOnceAndRejectsRestart() {
        let queue = OperationQueue()
        queue.isSuspended = true
        let engine = CovFQueryEngine()
        let service = StorageKeysQueryService(connection: engine, operationManager: OperationManager(operationQueue: queue),
                                              prefixKeyClosure: { Data() }, mapper: AnyMapper(mapper: CovFDataMapper()))
        var errors = 0
        service.cancel()
        service.start { result in
            XCTAssertTrue(covFFailure(result) is StorageKeysQueryService<Data>.InternalError)
            errors += 1
        }
        service.cancel()
        service.cancel()
        service.start { result in
            XCTAssertTrue(covFFailure(result) is StorageKeysQueryService<Data>.InternalError)
            errors += 1
        }
        XCTAssertEqual(errors, 2)
        queue.cancelAllOperations()
        queue.isSuspended = false
        queue.waitUntilAllOperationsAreFinished()
        XCTAssertTrue(engine.methods.isEmpty)
    }

    func testLongrunOperationReturnsEmptySuccessfulPage() throws {
        let engine = CovFQueryEngine()
        engine.replies = [[]]
        let operation = query(engine).longrunOperation()
        let queue = OperationQueue()
        queue.addOperations([operation], waitUntilFinished: true)
        XCTAssertEqual(try XCTUnwrap(operation.result).get(), [])
        XCTAssertEqual(engine.methods.count, 1)
    }

    func testStorageSubscriptionPersistsInsertUpdateDeleteAndNoChange() throws {
        let repository = CovFRepository<ChainStorageItem>()
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let subscription = CovFStorageChild(repository: repository, queue: queue)
        for (index, data) in [Data([1]), Data([2]), Data([2]), nil, nil].enumerated() {
            let done = expectation(description: "change \(index)")
            subscription.completion = { result, hash in
                XCTAssertEqual(hash, Data([9]))
                do {
                    let change = try result.get()
                    switch (index, change) {
                    case (0, .insert(let item)), (1, .update(let item)): XCTAssertEqual(item.data, data)
                    case (3, .delete(let id)): XCTAssertEqual(id, "local")
                    case (2, nil), (4, nil): break
                    default: XCTFail("Unexpected change \(String(describing: change))")
                    }
                } catch { XCTFail("\(error)") }
                done.fulfill()
            }
            subscription.processUpdate(data, blockHash: Data([9]))
            wait(for: [done], timeout: 5)
            XCTAssertEqual(repository.items.map(\.data), data.map { [$0] } ?? [])
        }
    }

    func testStorageSubscriptionReportsFetchFailureWithoutWriting() {
        let repository = CovFRepository<ChainStorageItem>()
        repository.failure = NSError(domain: "fetch", code: 3)
        let subscription = CovFStorageChild(repository: repository, queue: OperationQueue())
        let done = expectation(description: "fetch failed")
        subscription.completion = { result, hash in
            XCTAssertNil(hash)
            XCTAssertEqual((covFFailure(result) as NSError?)?.domain, "fetch")
            done.fulfill()
        }
        subscription.processUpdate(Data([1]), blockHash: nil)
        wait(for: [done], timeout: 5)
        XCTAssertTrue(repository.items.isEmpty)
    }

    func testSuffixMapperDecodesLittleEndianAndRejectsShortOrUnavailableData() throws {
        let runtime = try CovFFixtures.runtime(path: .activeEra, type: "u32", definitions: #"{"types":{}}"#)
        let mapper = StorageKeySuffixMapper<String>(type: "u32", suffixLength: 4, coderFactoryClosure: { runtime.factory })
        XCTAssertEqual(mapper.map(input: Data([0xaa, 42, 0, 0, 0])), "42")
        XCTAssertNil(mapper.map(input: Data([1])))
        let failing = StorageKeySuffixMapper<String>(type: "u32", suffixLength: 4, coderFactoryClosure: { throw NSError(domain: "coder", code: 1) })
        XCTAssertNil(failing.map(input: Data(repeating: 0, count: 4)))
    }

    private func query(_ engine: CovFQueryEngine, prefix: @escaping () throws -> Data = { Data([0xaa]) }) -> StorageKeysQueryService<Data> {
        StorageKeysQueryService(connection: engine, operationManager: OperationManager(), prefixKeyClosure: prefix,
                                mapper: AnyMapper(mapper: CovFDataMapper()), pageSize: 2)
    }
}

func covFFailure<T>(_ result: Result<T, Error>) -> Error? {
    if case let .failure(error) = result { return error }
    return nil
}

private struct CovFDataMapper: Mapping {
    func map(input: Data) -> Data { input }
}

private final class CovFStorageChild: BaseStorageChildSubscription<ChainStorageItem> {
    var completion: ((Result<DataProviderChange<ChainStorageItem>?, Error>, Data?) -> Void)?
    init(repository: CovFRepository<ChainStorageItem>, queue: OperationQueue) {
        super.init(remoteStorageKey: Data([1]), localStorageKey: "local", storage: AnyDataProviderRepository(repository),
                   operationManager: OperationManager(operationQueue: queue), logger: Logger.shared)
    }

    override func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>, blockHash: Data?) { completion?(result, blockHash) }
}

final class CovFQueryEngine: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }
    var replies: [Any] = []
    var failure: Error?
    var methods: [String] = []
    var parameters: [Any] = []
    var subscriptionParameters: [[[String]]] = []
    var unsubscribed: [UInt16] = []
    var subscriptionError: Error?
    var update: ((Data) throws -> Void)?
    var fail: ((Error, Bool) -> Void)?
    private var identifier: UInt16 = 0

    func callMethod<P: Codable, T: Decodable>(
        _ method: String, params: P?, options _: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        methods.append(method)
        if let params { parameters.append(try JSONSerialization.jsonObject(with: JSONEncoder().encode(params))) }
        if let failure { closure?(.failure(failure)) }
        else {
            let value = replies.isEmpty ? [] : replies.removeFirst()
            do {
                let data = try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
                closure?(.success(try JSONDecoder().decode(T.self, from: data)))
            } catch { closure?(.failure(error)) }
        }
        return generateRequestId()
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        if let subscriptionError { throw subscriptionError }
        if let params = params as? [[String]] { subscriptionParameters.append(params) }
        update = { updateClosure(try JSONDecoder().decode(T.self, from: $0)) }
        fail = failureClosure
        return generateRequestId()
    }

    func generateRequestId() -> UInt16 { identifier += 1; return identifier }
    func cancelForIdentifier(_: UInt16) {}
    func addSubscription(_: JSONRPCSubscribing) {}
    func reconnect(url: URL) { self.url = url }
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_ identifier: UInt16) throws { unsubscribed.append(identifier) }
}
