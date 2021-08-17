import XCTest
@testable import fearless
import Cuckoo
import RobinHood

class RuntimeProviderTests: XCTestCase {
    func testTypeCatalogSuccessfullCreated() throws {
        // given

        let chainModel = ChainModelGenerator.generate(count: 1, withTypes: true).first!
        let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()
        let eventCenter = MockEventCenterProtocol()

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

        stub(filesOperationFactory) { stub in
            stub.fetchCommonTypesOperation().then {
                commonTypesFetched.fulfill()
                return CompoundOperationWrapper.createWithResult(commonTypes)
            }

            stub.fetchChainTypesOperation(for: any()).then { chainId in
                chainTypesFetched.fulfill()
                return CompoundOperationWrapper.createWithResult(chainTypes)
            }
        }

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is RuntimeCoderCreated {
                    eventSent.fulfill()
                }
            }
        }

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

        runtimeProvider.setup()

        // then

        wait(for: [commonTypesFetched, chainTypesFetched, eventSent], timeout: 10)

        XCTAssertNotNil(runtimeProvider.snapshot)

    }

    func testTypeCatalogCreationFailureIsHandled() throws {
        // given

        let chainModel = ChainModelGenerator.generate(count: 1, withTypes: true).first!
        let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()
        let eventCenter = MockEventCenterProtocol()

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

        let chainTypeUrl = Bundle.main.url(forResource: "runtime-westend", withExtension: "json")!
        let chainTypes = try Data(contentsOf: chainTypeUrl)

        // when

        let commonTypesFetched = XCTestExpectation()
        let chainTypesFetched = XCTestExpectation()
        let eventSent = XCTestExpectation()

        stub(filesOperationFactory) { stub in
            stub.fetchCommonTypesOperation().then {
                commonTypesFetched.fulfill()
                return CompoundOperationWrapper.createWithError(BaseOperationError.unexpectedDependentResult)
            }

            stub.fetchChainTypesOperation(for: any()).then { chainId in
                chainTypesFetched.fulfill()
                return CompoundOperationWrapper.createWithResult(chainTypes)
            }
        }

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is RuntimeCoderCreationFailed {
                    eventSent.fulfill()
                }
            }
        }

        runtimeProvider.setup()

        // then

        wait(for: [commonTypesFetched, chainTypesFetched, eventSent], timeout: 10)

        XCTAssertNil(runtimeProvider.snapshot)
    }

    func testCommonTypesChangeIsHandled() {

    }

    func testRuntimeMetadataSyncCompletionIsHandled() {

    }

    func testOwnTypesChangeIsHandled() {

    }
}
