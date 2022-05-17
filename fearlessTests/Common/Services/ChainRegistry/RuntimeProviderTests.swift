import XCTest
@testable import fearless
import Cuckoo
import RobinHood
import FearlessUtils

class RuntimeProviderTests: XCTestCase {
    func testTypeCatalogSuccessfullCreated() throws {
        // given

        let commonTypesUrl = Bundle.main.url(forResource: "runtime-default", withExtension: "json")!
        let commonTypes = try Data(contentsOf: commonTypesUrl)

        let chainTypeUrl = Bundle.main.url(forResource: "runtime-westend", withExtension: "json")!
        let chainTypes = try Data(contentsOf: chainTypeUrl)

        let metadataUrl = Bundle(for: type(of: self)).url(
            forResource: "westend-metadata",
            withExtension: ""
        )!

        let hex = try String(contentsOf: metadataUrl)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let metadata = try Data(hexString: hex)

        // when

        let commonTypesFetched = XCTestExpectation()
        let chainTypesFetched = XCTestExpectation()
        let eventSent = XCTestExpectation()
        let visitorAdd = XCTestExpectation()

        let runtimeProvider = performSetup(with: { event in
            if event is RuntimeCoderCreated {
                eventSent.fulfill()
            }
        }, commonTypesFetchClosure: {
            commonTypesFetched.fulfill()
            return CompoundOperationWrapper.createWithResult(commonTypes)
        }, chainTypesFetchClosure: {
            chainTypesFetched.fulfill()
            return CompoundOperationWrapper.createWithResult(chainTypes)
        }, runtimeMetadataClosure: {
            metadata
        }, eventVisitorClosure: { _ in
            visitorAdd.fulfill()
        })

        runtimeProvider.setup()

        // then

        wait(for: [visitorAdd, commonTypesFetched, chainTypesFetched, eventSent], timeout: 10)

        XCTAssertNotNil(runtimeProvider.snapshot)

    }

    func testTypeCatalogCreationFailureIsHandled() throws {
        // given

        let chainTypeUrl = Bundle.main.url(forResource: "runtime-westend", withExtension: "json")!
        let chainTypes = try Data(contentsOf: chainTypeUrl)

        // when

        let commonTypesFetched = XCTestExpectation()
        let chainTypesFetched = XCTestExpectation()
        let eventSent = XCTestExpectation()

        let runtimeProvider = performSetup(with: { event in
            if event is RuntimeCoderCreationFailed {
                eventSent.fulfill()
            }
        }, commonTypesFetchClosure: {
            commonTypesFetched.fulfill()
            return CompoundOperationWrapper.createWithError(BaseOperationError.unexpectedDependentResult)
        }, chainTypesFetchClosure: {
            chainTypesFetched.fulfill()
            return CompoundOperationWrapper.createWithResult(chainTypes)
        }, runtimeMetadataClosure: {
            nil
        }, eventVisitorClosure: nil)

        runtimeProvider.setup()

        // then

        wait(for: [commonTypesFetched, chainTypesFetched, eventSent], timeout: 10)

        XCTAssertNil(runtimeProvider.snapshot)
    }

    func testCommonTypesChangeIsHandled() throws {
        // given

        let commonTypesUrl = Bundle.main.url(forResource: "runtime-default", withExtension: "json")!
        let commonTypes = try Data(contentsOf: commonTypesUrl)

        let emptyCommonTypesJson = JSON.dictionaryValue(["types": JSON.dictionaryValue([:])])
        let emptyCommonTypes = try JSONEncoder().encode(emptyCommonTypesJson)

        let chainTypeUrl = Bundle.main.url(forResource: "runtime-westend", withExtension: "json")!
        let chainTypes = try Data(contentsOf: chainTypeUrl)

        let metadataUrl = Bundle(for: type(of: self)).url(
            forResource: "westend-metadata",
            withExtension: ""
        )!

        let hex = try String(contentsOf: metadataUrl)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let metadata = try Data(hexString: hex)

        var isSetup = true

        let setupExpectation = XCTestExpectation()
        let completionExpectation = XCTestExpectation()

        let runtimeProvider = performSetup(with: { event in
            if event is RuntimeCoderCreated {
                if isSetup {
                    setupExpectation.fulfill()
                } else {
                    completionExpectation.fulfill()
                }
            }
        }, commonTypesFetchClosure: {
            if isSetup {
                return CompoundOperationWrapper.createWithResult(emptyCommonTypes)
            } else {
                return CompoundOperationWrapper.createWithResult(commonTypes)
            }
        }, chainTypesFetchClosure: {
            return CompoundOperationWrapper.createWithResult(chainTypes)
        }, runtimeMetadataClosure: {
            return metadata
        }, eventVisitorClosure: nil)

        // when

        runtimeProvider.setup()

        wait(for: [setupExpectation], timeout: 10)

        isSetup = false

        let event = RuntimeCommonTypesSyncCompleted(
            fileHash: try StorageHasher.twox256.hash(data: commonTypes).toHex()
        )

        runtimeProvider.processRuntimeCommonTypesSyncCompleted(event: event)

        // then

        wait(for: [completionExpectation], timeout: 10)

        XCTAssertNotNil(runtimeProvider.snapshot)
    }

    func testRuntimeMetadataSyncCompletionIsHandled() throws {
        // given

        let commonTypesUrl = Bundle.main.url(forResource: "runtime-default", withExtension: "json")!
        let commonTypes = try Data(contentsOf: commonTypesUrl)

        let chainTypeUrl = Bundle.main.url(forResource: "runtime-westend", withExtension: "json")!
        let chainTypes = try Data(contentsOf: chainTypeUrl)

        let metadataUrl = Bundle(for: type(of: self)).url(
            forResource: "westend-metadata",
            withExtension: ""
        )!

        let hex = try String(contentsOf: metadataUrl)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let metadata = try Data(hexString: hex)

        var isSetup = true

        let setupExpectation = XCTestExpectation()
        let completionExpectation = XCTestExpectation()

        let runtimeProvider = performSetup(with: { event in
            if event is RuntimeCoderCreated {
                if isSetup {
                    setupExpectation.fulfill()
                } else {
                    completionExpectation.fulfill()
                }
            }
        }, commonTypesFetchClosure: {
            return CompoundOperationWrapper.createWithResult(commonTypes)
        }, chainTypesFetchClosure: {
            return CompoundOperationWrapper.createWithResult(chainTypes)
        }, runtimeMetadataClosure: {
            return metadata
        }, eventVisitorClosure: nil)

        // when

        runtimeProvider.setup()

        wait(for: [setupExpectation], timeout: 10)

        isSetup = false

        let event = RuntimeMetadataSyncCompleted(
            chainId: runtimeProvider.chainId,
            version: RuntimeVersion(specVersion: 2, transactionVersion: 2)
        )

        runtimeProvider.processRuntimeChainMetadataSyncCompleted(event: event)

        // then

        wait(for: [completionExpectation], timeout: 10)

        XCTAssertNotNil(runtimeProvider.snapshot)
    }

    func testChainTypesChangeIsHandled() throws {
        // given

        let commonTypesUrl = Bundle.main.url(forResource: "runtime-default", withExtension: "json")!
        let commonTypes = try Data(contentsOf: commonTypesUrl)

        let otherChainTypeUrl = Bundle.main.url(forResource: "runtime-kusama", withExtension: "json")!
        let otherChainTypes = try Data(contentsOf: otherChainTypeUrl)

        let chainTypeUrl = Bundle.main.url(forResource: "runtime-westend", withExtension: "json")!
        let chainTypes = try Data(contentsOf: chainTypeUrl)

        let metadataUrl = Bundle(for: type(of: self)).url(
            forResource: "westend-metadata",
            withExtension: ""
        )!

        let hex = try String(contentsOf: metadataUrl)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let metadata = try Data(hexString: hex)

        var isSetup = true

        let setupExpectation = XCTestExpectation()
        let completionExpectation = XCTestExpectation()

        let runtimeProvider = performSetup(with: { event in
            if event is RuntimeCoderCreated {
                if isSetup {
                    setupExpectation.fulfill()
                } else {
                    completionExpectation.fulfill()
                }
            }
        }, commonTypesFetchClosure: {
            return CompoundOperationWrapper.createWithResult(commonTypes)
        }, chainTypesFetchClosure: {
            if isSetup {
                return CompoundOperationWrapper.createWithResult(otherChainTypes)
            } else {
                return CompoundOperationWrapper.createWithResult(chainTypes)
            }
        }, runtimeMetadataClosure: {
            return metadata
        }, eventVisitorClosure: nil)

        // when

        runtimeProvider.setup()

        wait(for: [setupExpectation], timeout: 10)

        isSetup = false

        let event = RuntimeChainTypesSyncCompleted(
            chainId: runtimeProvider.chainId,
            fileHash: try StorageHasher.twox256.hash(data: chainTypes).toHex()
        )

        runtimeProvider.processRuntimeChainTypesSyncCompleted(event: event)

        // then

        wait(for: [completionExpectation], timeout: 10)

        XCTAssertNotNil(runtimeProvider.snapshot)
    }

    func testCanReceiveSnapshot() throws {
        // given

        let commonTypesUrl = Bundle.main.url(forResource: "runtime-default", withExtension: "json")!
        let commonTypes = try Data(contentsOf: commonTypesUrl)

        let chainTypeUrl = Bundle.main.url(forResource: "runtime-westend", withExtension: "json")!
        let chainTypes = try Data(contentsOf: chainTypeUrl)

        let metadataUrl = Bundle(for: type(of: self)).url(
            forResource: "westend-metadata",
            withExtension: ""
        )!

        let hex = try String(contentsOf: metadataUrl)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let metadata = try Data(hexString: hex)

        // when

        let runtimeProvider = performSetup(with: { _ in }, commonTypesFetchClosure: {
            return CompoundOperationWrapper.createWithResult(commonTypes)
        }, chainTypesFetchClosure: {
            return CompoundOperationWrapper.createWithResult(chainTypes)
        }, runtimeMetadataClosure: {
            metadata
        }, eventVisitorClosure: nil)

        runtimeProvider.setup()

        // then

        let fetchCoderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        OperationQueue().addOperations([fetchCoderFactoryOperation], waitUntilFinished: true)

        XCTAssertNoThrow(try fetchCoderFactoryOperation.extractNoCancellableResultData())
    }

    private func performSetup(
        with eventHandlingClosure: @escaping (EventProtocol) -> (),
        commonTypesFetchClosure: @escaping () -> CompoundOperationWrapper<Data?>,
        chainTypesFetchClosure: @escaping () -> CompoundOperationWrapper<Data?>,
        runtimeMetadataClosure: @escaping () -> Data?,
        eventVisitorClosure: ((EventVisitorProtocol) -> ())?
    ) -> RuntimeProvider {
        let chainModel = ChainModelGenerator.generate(count: 1, withTypes: true).first!
        let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()

        let eventCenter = MockEventCenterProtocol()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                eventHandlingClosure(event)
            }

            stub.add(observer: any(), dispatchIn: any()).then { (visitor, queue) in
                eventVisitorClosure?(visitor)
            }
        }

        let storageFacade = SubstrateStorageTestFacade()
        let repository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> = storageFacade.createRepository()

        let snapshotOperationFactory = RuntimeSnapshotFactory(
            chainId: chainModel.chainId,
            filesOperationFactory: filesOperationFactory,
            repository: AnyDataProviderRepository(repository)
        )

        let operationQueue = OperationQueue()

        let runtimeProvider = RuntimeProvider(
            chainModel: chainModel,
            snapshotOperationFactory: snapshotOperationFactory,
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )

        stub(filesOperationFactory) { stub in
            stub.fetchCommonTypesOperation().then {
                return commonTypesFetchClosure()
            }

            stub.fetchChainTypesOperation(for: any()).then { chainId in
                return chainTypesFetchClosure()
            }
        }

        if let metadata = runtimeMetadataClosure() {
            let metadataItemSaveOperation = repository.saveOperation({
                let item = RuntimeMetadataItem(
                    chain: chainModel.chainId,
                    version: 1,
                    txVersion: 1,
                    metadata: metadata
                )

                return [item]
            }, { [] })

            operationQueue.addOperations([metadataItemSaveOperation], waitUntilFinished: true)
        }

        return runtimeProvider
    }
}
