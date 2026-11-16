import XCTest
import RobinHood
import SSFModels
@testable import fearless

final class CovJNetManagmentInteractorOutputSpy: NetworkManagmentInteractorOutput {
    var results: [Result<[ChainModel], Error>] = []
    var wallets: [MetaAccountModel] = []

    func didReceiveChains(result: Result<[ChainModel], Error>) { results.append(result) }
    func didReceiveUpdated(wallet: MetaAccountModel) { wallets.append(wallet) }

    func chainIds(at index: Int) -> Set<String>? {
        guard index < results.count, case let .success(chains) = results[index] else { return nil }
        return Set(chains.map(\.chainId))
    }

    func error(at index: Int) -> Error? {
        guard index < results.count, case let .failure(error) = results[index] else { return nil }
        return error
    }
}

final class CovJNetManagmentInteractorTests: XCTestCase {
    private let alpha = CovJNetFixture.chain(name: "Alpha")
    private let beta = CovJNetFixture.chain(name: "Beta")

    private func makeInteractor(
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount(),
        repository: CovJMemoryRepository<ChainModel>,
        chains: [ChainModel]?,
        events: CovJNetEventCenterSpy
    ) -> NetworkManagmentInteractor {
        NetworkManagmentInteractor(
            wallet: wallet,
            chainRepository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            chainModels: chains,
            eventCenter: events
        )
    }

    func testProvidedChainsAreDeliveredAtOnceAndChainEventsAreIgnored() {
        let events = CovJNetEventCenterSpy()
        let repository = CovJMemoryRepository<ChainModel>([beta])
        let interactor = makeInteractor(repository: repository, chains: [alpha], events: events)
        let output = CovJNetManagmentInteractorOutputSpy()

        interactor.setup(with: output)

        XCTAssertEqual(output.results.count, 1)
        XCTAssertEqual(output.chainIds(at: 0), [alpha.chainId])
        XCTAssertEqual(events.addedQueues.count, 1)
        XCTAssertTrue(events.addedQueues.compactMap { $0 }.first === DispatchQueue.main)

        interactor.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: [beta]))
        interactor.processChainSyncDidComplete(event: ChainSyncDidComplete(newOrUpdatedChains: [beta], removedChains: []))
        CovJWait.drain(0.15)

        XCTAssertEqual(output.results.count, 1)
        XCTAssertTrue(output.wallets.isEmpty)
    }

    func testStoredChainsAreFetchedOnSetupAndRefetchedAfterChainEvents() throws {
        let events = CovJNetEventCenterSpy()
        let repository = CovJMemoryRepository<ChainModel>([alpha, beta])
        let interactor = makeInteractor(repository: repository, chains: nil, events: events)
        let output = CovJNetManagmentInteractorOutputSpy()

        interactor.setup(with: output)
        XCTAssertTrue(CovJWait.until { output.results.count == 1 })
        XCTAssertEqual(output.chainIds(at: 0), [alpha.chainId, beta.chainId])

        interactor.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: [alpha]))
        XCTAssertTrue(CovJWait.until { output.results.count == 2 })
        XCTAssertEqual(output.chainIds(at: 1), [alpha.chainId, beta.chainId])

        interactor.processChainSyncDidComplete(event: ChainSyncDidComplete(newOrUpdatedChains: [], removedChains: [beta]))
        XCTAssertTrue(CovJWait.until { output.results.count == 3 })

        repository.failure = CovJError("disk unavailable")
        interactor.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: [beta]))
        XCTAssertTrue(CovJWait.until { output.results.count == 4 })
        XCTAssertEqual(output.error(at: 3) as? CovJError, CovJError("disk unavailable"))
        XCTAssertTrue(events.events.isEmpty)
    }

    func testSelectingTheStoredFilterSavesNothingAndDeinitRemovesObserver() {
        let events = CovJNetEventCenterSpy()
        let wallet = AccountGenerator.generateMetaAccount().replacingNetworkManagmentFilter("popular")
        let output = CovJNetManagmentInteractorOutputSpy()
        var interactor: NetworkManagmentInteractor? = makeInteractor(
            wallet: wallet,
            repository: CovJMemoryRepository<ChainModel>(),
            chains: [],
            events: events
        )

        interactor?.setup(with: output)
        XCTAssertEqual(output.chainIds(at: 0), [])
        interactor?.didSelect("popular")
        CovJWait.drain(0.15)

        XCTAssertTrue(output.wallets.isEmpty)
        XCTAssertTrue(events.events.isEmpty)
        XCTAssertEqual(events.removals, 0)

        interactor = nil
        XCTAssertEqual(events.removals, 1)
    }
}
