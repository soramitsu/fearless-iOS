import XCTest
@testable import fearless
import FearlessFoundation
import RobinHood
import SSFModels
import SSFUtils

final class ChainSyncServiceTests: XCTestCase {
    func testSyncUpAppliesFetchedChainsAndPreservesSelectedNode() throws {
        let fixture = makeFixture()
        let generatedChains = ChainModelGenerator.generate(count: 3)

        let localExisting = generatedChains[0]
        let selectedNode = try XCTUnwrap(localExisting.nodes.first)
        localExisting.selectedNode = selectedNode

        let remoteExisting = copyChain(localExisting, name: "Updated \(localExisting.name)")
        let remoteNew = generatedChains[1]
        let localRemoved = generatedChains[2]

        try save([localExisting, localRemoved], in: fixture.repository, using: fixture.operationQueue)

        fixture.dataFactory.results = [
            .success(try JSONEncoder().encode([remoteExisting, remoteNew]))
        ]

        let startExpectation = expectation(description: "Chain sync started")
        let completionExpectation = expectation(description: "Chain sync completed")
        fixture.eventCenter.onNotify = { event in
            switch event {
            case is ChainSyncDidStart:
                startExpectation.fulfill()
            case let event as ChainSyncDidComplete:
                XCTAssertEqual(Set(event.newOrUpdatedChains.map(\.chainId)), [
                    remoteExisting.chainId,
                    remoteNew.chainId
                ])
                XCTAssertEqual(event.removedChains.map(\.chainId), [localRemoved.chainId])
                completionExpectation.fulfill()
            default:
                break
            }
        }

        fixture.service.syncUp()

        wait(
            for: [startExpectation, completionExpectation],
            timeout: Constants.defaultExpectationDuration,
            enforceOrder: true
        )

        let fetchedChains = try fetchAll(from: fixture.repository, using: fixture.operationQueue)
        let fetchedById = Dictionary(uniqueKeysWithValues: fetchedChains.map { ($0.chainId, $0) })

        XCTAssertEqual(Set(fetchedById.keys), [remoteExisting.chainId, remoteNew.chainId])
        XCTAssertEqual(fetchedById[remoteExisting.chainId]?.name, remoteExisting.name)
        XCTAssertEqual(fetchedById[remoteExisting.chainId]?.selectedNode, selectedNode)
        XCTAssertEqual(fetchedById[remoteNew.chainId]?.name, remoteNew.name)
    }

    func testSyncUpPublishesFailureAndKeepsLocalChainsWhenFetchFails() throws {
        let fixture = makeFixture()
        let localChains = ChainModelGenerator.generate(count: 2)

        try save(localChains, in: fixture.repository, using: fixture.operationQueue)

        fixture.dataFactory.results = [
            .failure(ChainSyncServiceTestError.fetchFailed)
        ]

        let failureExpectation = expectation(description: "Chain sync failed")
        fixture.eventCenter.onNotify = { event in
            guard let event = event as? ChainSyncDidFail else {
                return
            }

            XCTAssertTrue(event.error is ChainSyncServiceTestError)
            failureExpectation.fulfill()
        }

        fixture.service.syncUp()

        wait(for: [failureExpectation], timeout: Constants.defaultExpectationDuration)

        let fetchedChains = try fetchAll(from: fixture.repository, using: fixture.operationQueue)

        XCTAssertEqual(Set(fetchedChains.map(\.chainId)), Set(localChains.map(\.chainId)))
    }
}

private extension ChainSyncServiceTests {
    typealias Fixture = (
        service: ChainSyncService,
        repository: CoreDataRepository<ChainModel, CDChain>,
        dataFactory: ChainSyncDataOperationFactoryStub,
        eventCenter: RecordingChainSyncEventCenter,
        operationQueue: OperationQueue
    )

    func makeFixture() -> Fixture {
        let storageFacade = SubstrateStorageTestFacade()
        let repository: CoreDataRepository<ChainModel, CDChain> = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(ChainModelMapper())
        )
        let dataFactory = ChainSyncDataOperationFactoryStub()
        let eventCenter = RecordingChainSyncEventCenter()
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        let service = ChainSyncService(
            chainsUrl: URL(string: "https://example.com/chains.json")!,
            dataFetchFactory: dataFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            retryStrategy: NoRetryStrategy(),
            applicationHandler: ApplicationHandlerStub()
        )

        return (service, repository, dataFactory, eventCenter, operationQueue)
    }

    func save(
        _ chains: [ChainModel],
        in repository: CoreDataRepository<ChainModel, CDChain>,
        using operationQueue: OperationQueue
    ) throws {
        let saveOperation = repository.saveOperation({ chains }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        if case let .failure(error) = saveOperation.result {
            throw error
        }
    }

    func fetchAll(
        from repository: CoreDataRepository<ChainModel, CDChain>,
        using operationQueue: OperationQueue
    ) throws -> [ChainModel] {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

        switch fetchOperation.result {
        case let .success(chains):
            return chains
        case let .failure(error):
            throw error
        case .none:
            XCTFail("Expected chain fetch result")
            return []
        }
    }

    func copyChain(_ chain: ChainModel, name: String) -> ChainModel {
        ChainModel(
            rank: chain.rank,
            disabled: chain.disabled,
            chainId: chain.chainId,
            parentId: chain.parentId,
            paraId: chain.paraId,
            name: name,
            assets: chain.assets,
            xcm: chain.xcm,
            nodes: chain.nodes,
            addressPrefix: chain.addressPrefix,
            types: chain.types,
            icon: chain.icon,
            options: chain.options,
            externalApi: chain.externalApi,
            selectedNode: nil,
            customNodes: chain.customNodes,
            iosMinAppVersion: chain.iosMinAppVersion,
            identityChain: chain.identityChain
        )
    }
}

private enum ChainSyncServiceTestError: Error {
    case fetchFailed
}

private final class ChainSyncDataOperationFactoryStub: DataOperationFactoryProtocol {
    var results: [Result<Data, Error>] = []

    func fetchData(from _: URL) -> BaseOperation<Data> {
        ClosureOperation<Data> {
            guard !self.results.isEmpty else {
                throw ChainSyncServiceTestError.fetchFailed
            }

            return try self.results.removeFirst().get()
        }
    }
}

private final class RecordingChainSyncEventCenter: EventCenterProtocol {
    var onNotify: ((EventProtocol) -> Void)?

    func notify(with event: EventProtocol) {
        onNotify?(event)
    }

    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}
    func remove(observer _: EventVisitorProtocol) {}
}

private final class ApplicationHandlerStub: ApplicationHandlerProtocol {
    weak var delegate: ApplicationHandlerDelegate?
}

private struct NoRetryStrategy: ReconnectionStrategyProtocol {
    func reconnectAfter(attempt _: Int) -> TimeInterval? {
        nil
    }
}
