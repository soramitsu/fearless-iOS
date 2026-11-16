import XCTest
import UIKit
import RobinHood
import SoraFoundation
import SSFModels
import Web3
@testable import fearless

/// Lane-J network fixtures: chains whose nodes live on `.invalid` hosts, so nothing here can reach a real node.
enum CovJNetFixture {
    static var locale: Locale { LocalizationManager.shared.selectedLocale }

    static func url(_ host: String) -> URL {
        URL(string: "wss://\(host.lowercased()).invalid") ?? URL(fileURLWithPath: "/")
    }

    static func node(_ name: String) -> ChainNodeModel {
        ChainNodeModel(url: url(name), name: name, apikey: nil)
    }

    static func chain(
        name: String,
        rank: UInt16? = nil,
        nodes: Set<ChainNodeModel> = [],
        custom: Set<ChainNodeModel>? = nil,
        selected: ChainNodeModel? = nil,
        icon: URL? = nil
    ) -> ChainModel {
        ChainModel(
            rank: rank,
            disabled: false,
            chainId: "covjnet-\(name.lowercased())",
            parentId: nil,
            paraId: nil,
            name: name,
            xcm: nil,
            nodes: nodes,
            addressPrefix: 42,
            types: nil,
            icon: icon,
            options: nil,
            externalApi: nil,
            selectedNode: selected,
            customNodes: custom,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

/// Records every event and observer registration instead of dispatching them.
final class CovJNetEventCenterSpy: EventCenterProtocol {
    private let lock = NSLock()
    private var storedEvents: [EventProtocol] = []
    private var storedQueues: [DispatchQueue?] = []
    private var storedRemovals = 0

    var events: [EventProtocol] {
        lock.lock()
        defer { lock.unlock() }
        return storedEvents
    }

    var addedQueues: [DispatchQueue?] {
        lock.lock()
        defer { lock.unlock() }
        return storedQueues
    }

    var removals: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedRemovals
    }

    var chainUpdates: [ChainsUpdatedEvent] { events.compactMap { $0 as? ChainsUpdatedEvent } }

    func notify(with event: EventProtocol) {
        lock.lock()
        storedEvents.append(event)
        lock.unlock()
    }

    func add(observer _: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) {
        lock.lock()
        storedQueues.append(queue)
        lock.unlock()
    }

    func remove(observer _: EventVisitorProtocol) {
        lock.lock()
        storedRemovals += 1
        lock.unlock()
    }
}

/// A chain registry with no connections; it only records which chains were asked to reconnect.
final class CovJNetChainRegistryStub: ChainRegistryProtocol {
    private(set) var resets: [ChainModel.Id] = []

    var availableChainIds: Set<ChainModel.Id>? { nil }
    var availableChains: [ChainModel] { [] }
    var chainsTypesMap: [String: Data] { [:] }

    func resetConnection(for chainId: ChainModel.Id) { resets.append(chainId) }
    func retryConnection(for _: ChainModel.Id) {}
    func getConnection(for _: ChainModel.Id) -> ChainConnection? { nil }
    func getEthereumConnection(for _: ChainModel.Id) -> Web3.Eth? { nil }
    func getTonApiClientFactory() throws -> TonAPIClientFactory { throw ChainRegistryError.connectionUnavailable }
    func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? { nil }
    func getChain(for _: ChainModel.Id) -> ChainModel? { nil }

    func chainsSubscribe(
        _: AnyObject,
        runningInQueue _: DispatchQueue,
        updateClosure _: @escaping ([DataProviderChange<ChainModel>]) -> Void
    ) {}

    func chainsUnsubscribe(_: AnyObject) {}
    func syncUp() {}
    func performHotBoot() {}
    func performColdBoot() {}
    func subscribeToChains() {}
}

/// Answers the "which chain is this node?" probe with a canned result instead of opening a socket.
final class CovJNetSubstrateFactoryStub: SubstrateOperationFactoryProtocol {
    var result: Result<String, Error>
    private(set) var urls: [URL] = []

    init(result: Result<String, Error> = .success("covjnet-genesis")) {
        self.result = result
    }

    func fetchChainOperation(_ url: URL) -> BaseOperation<String> {
        urls.append(url)
        let result = self.result
        return ClosureOperation { try result.get() }
    }
}

/// Async chain repository that keeps every saved chain in save order.
final class CovJNetChainStore: AsyncCoreDataRepository {
    typealias Model = ChainModel

    private let lock = NSLock()
    private var stored: [ChainModel] = []

    var saved: [ChainModel] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    private func record(_ models: [ChainModel]) {
        lock.lock()
        stored.append(contentsOf: models)
        lock.unlock()
    }

    func fetch(by modelIds: [String], options _: RepositoryFetchOptions) async throws -> [ChainModel] {
        saved.filter { modelIds.contains($0.chainId) }
    }

    func fetch(by modelId: String, options _: RepositoryFetchOptions) async throws -> ChainModel? {
        saved.last { $0.chainId == modelId }
    }

    func fetchAll(with _: RepositoryFetchOptions) async throws -> [ChainModel] {
        saved
    }

    func save(models: [ChainModel], deleteIds _: [String]) async {
        record(models)
    }
}

/// Wraps any controller as a `ControllerBackedProtocol` view.
final class CovJNetBacked: ControllerBackedProtocol {
    let controller: UIViewController
    var isSetup: Bool { true }

    init(_ controller: UIViewController) {
        self.controller = controller
    }
}

final class CovJNetStatusSpy: ApplicationStatusPresentable {
    var presented: [(ApplicationStatusAlertEvent, Bool)] = []
    var dismissed: [(ApplicationStatusAlertEvent?, Bool)] = []

    func presentStatus(with viewModel: ApplicationStatusAlertEvent, animated: Bool) {
        presented.append((viewModel, animated))
    }

    func dismissStatus(with viewModel: ApplicationStatusAlertEvent?, animated: Bool) {
        dismissed.append((viewModel, animated))
    }
}

final class CovJNetSupportTests: XCTestCase {
    func testAvailabilityLayerShowsOfflineAndDismissesWithReconnectedStatus() throws {
        let view = CovJNetStatusSpy()
        let presenter = NetworkAvailabilityLayerPresenter(view: view, localizationManager: LocalizationManager.shared)
        let languages = CovJNetFixture.locale.rLanguages

        presenter.didDecideUnreachableStatusPresentation()

        XCTAssertEqual(view.presented.count, 1)
        XCTAssertTrue(view.dismissed.isEmpty)
        XCTAssertEqual(view.presented.first?.1, true)
        let offline = try XCTUnwrap(view.presented.first?.0 as? ConnectionOfflineEvent)
        XCTAssertFalse(offline.autoDismissing)
        XCTAssertEqual(offline.titleText, R.string.localizable.applicationStatusViewOfflineTitle(preferredLanguages: languages))
        XCTAssertEqual(offline.descriptionText, R.string.localizable.applicationStatusViewOfflineDescription(preferredLanguages: languages))

        presenter.didDecideReachableStatusPresentation()

        XCTAssertEqual(view.presented.count, 1)
        XCTAssertEqual(view.dismissed.count, 1)
        XCTAssertEqual(view.dismissed.first?.1, true)
        let online = try XCTUnwrap(view.dismissed.first?.0 as? ConnectionOnlineEvent)
        XCTAssertTrue(online.autoDismissing)
        XCTAssertEqual(online.titleText, R.string.localizable.applicationStatusViewReconnectedTitle(preferredLanguages: languages))

        presenter.applyLocalization()
        XCTAssertEqual(view.presented.count, 1)
        XCTAssertEqual(view.dismissed.count, 1)
    }

    func testNetworkInfoModeCombinesNameAndNodeEditing() {
        XCTAssertTrue(NetworkInfoMode.none.isEmpty)
        XCTAssertEqual(NetworkInfoMode.name.rawValue, 1)
        XCTAssertEqual(NetworkInfoMode.node.rawValue, 2)
        XCTAssertEqual(NetworkInfoMode.all.rawValue, 3)
        XCTAssertTrue(NetworkInfoMode.all.contains(.name))
        XCTAssertTrue(NetworkInfoMode.all.contains(.node))
        XCTAssertFalse(NetworkInfoMode.name.contains(.node))

        var mode = NetworkInfoMode(rawValue: 0)
        mode.insert(.node)
        XCTAssertEqual(mode, NetworkInfoMode.node)
        mode.insert(.name)
        XCTAssertEqual(mode, NetworkInfoMode.all)
    }

    func testFixturesStayOffline() {
        let node = CovJNetFixture.node("Alpha")
        XCTAssertEqual(node.url.absoluteString, "wss://alpha.invalid")
        let chain = CovJNetFixture.chain(name: "Alpha", rank: 3, nodes: [node], selected: node)
        XCTAssertEqual(chain.chainId, "covjnet-alpha")
        XCTAssertEqual(chain.rank, 3)
        XCTAssertEqual(chain.selectedNode, node)
        XCTAssertTrue(chain.nodes.allSatisfy { $0.url.host?.hasSuffix(".invalid") == true })
    }
}
