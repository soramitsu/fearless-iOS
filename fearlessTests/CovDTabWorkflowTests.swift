import Foundation
import SSFUtils
import UIKit
import XCTest

@testable import fearless

final class CovDTabServiceSpy: ServiceCoordinatorProtocol {
    var starts = 0
    var stops = 0
    var updates = 0
    func setup() { starts += 1 }
    func throttle() { stops += 1 }
    func updateOnAccountChange() { updates += 1 }
}

final class CovDTabImportSpy: KeystoreImportServiceProtocol {
    var definition: KeystoreDefinition?
    weak var observer: KeystoreImportObserver?
    func handle(url _: URL) -> Bool { false }
    func add(observer: KeystoreImportObserver) { self.observer = observer }
    func remove(observer _: KeystoreImportObserver) { observer = nil }
    func clear() { definition = nil }
}

final class CovDTabEventSpy: EventCenterProtocol {
    weak var observer: EventVisitorProtocol?
    func notify(with event: EventProtocol) { observer.map { event.accept(visitor: $0) } }
    func add(observer: EventVisitorProtocol, dispatchIn _: DispatchQueue?) { self.observer = observer }
    func remove(observer _: EventVisitorProtocol) { observer = nil }
}

final class CovDTabOutputSpy: MainTabBarInteractorOutputProtocol {
    var wallets: [String] = []
    var chains = 0
    var imports = 0
    var markets: [String] = []
    func didChangeSelectedAccount(_ account: MetaAccountModel) { wallets.append(account.metaId) }
    func didPrepareChains() { chains += 1 }
    func didRequestImportAccount() { imports += 1 }
    func didRequestPolkamarkt(marketId: String) { markets.append(marketId) }
}

final class CovDTabViewSpy: UIViewController, MainTabBarViewProtocol {
    var isPolkaswapUnavailable = true
    var replacements: [(Int, UIViewController)] = []
    func didReplaceView(for newView: UIViewController, for index: Int) { replacements.append((index, newView)) }
    func openPolkamarkt(marketId _: String) {}
}

final class CovDTabWorkflowTests: XCTestCase {
    func testInteractorRoutesPendingImportAndMarketAndStopsServicesOnRelease() throws {
        let events = CovDTabEventSpy()
        let service = CovDTabServiceSpy()
        let importer = CovDTabImportSpy()
        let output = CovDTabOutputSpy()
        importer.definition = KeystoreDefinition(
            address: nil, encoded: "fixture", encoding: KeystoreEncoding(content: [], type: [], version: "3"), meta: nil
        )
        _ = PolkamarktDeepLinkHandler.consumePending()
        defer { _ = PolkamarktDeepLinkHandler.consumePending() }
        let url = try XCTUnwrap(URL(string: "fearless://defi/polkamarkt/42"))
        XCTAssertTrue(PolkamarktDeepLinkHandler(eventCenter: events).handle(url: url))
        var interactor: MainTabBarInteractor? = MainTabBarInteractor(
            eventCenter: events, serviceCoordinator: service, keystoreImportService: importer
        )
        weak var weakInteractor = interactor
        interactor?.setup(with: output)
        XCTAssertEqual(service.starts, 1)
        XCTAssertEqual(output.chains, 1)
        XCTAssertEqual(output.imports, 1)
        XCTAssertEqual(output.markets, ["42"])
        XCTAssertNil(PolkamarktDeepLinkHandler.consumePending())
        importer.observer?.didUpdateDefinition(from: nil)
        XCTAssertEqual(output.imports, 2)
        importer.clear()
        importer.observer?.didUpdateDefinition(from: nil)
        XCTAssertEqual(output.imports, 2)
        events.notify(with: PolkamarktDeepLinkRequested(marketId: "43"))
        XCTAssertTrue(CovDFixtures.spin { output.markets == ["42", "43"] })
        interactor = nil
        XCTAssertNil(weakInteractor)
        XCTAssertEqual(service.stops, 1)
    }

    func testInteractorRefreshesChainsAndDropsAnAccountThatChangesBeforeDelivery() {
        let events = CovDTabEventSpy()
        let services = CovDTabServiceSpy()
        let first = CovDFixtures.wallet()
        let second = CovDFixtures.wallet()
        var selected = first
        let output = CovDTabOutputSpy()
        let interactor = MainTabBarInteractor(
            eventCenter: events, serviceCoordinator: services, keystoreImportService: CovDTabImportSpy(), selectedWalletProvider: { selected }
        )
        interactor.setup(with: output)
        events.notify(with: MetaAccountModelChangedEvent(account: first))
        selected = second
        interactor.processChainsSetupCompleted()
        interactor.processChainSyncDidComplete(event: ChainSyncDidComplete(newOrUpdatedChains: [], removedChains: []))
        interactor.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: []))
        XCTAssertTrue(CovDFixtures.spin { output.chains == 4 })
        XCTAssertTrue(output.wallets.isEmpty)
        events.notify(with: SelectedAccountChanged(account: second))
        XCTAssertTrue(CovDFixtures.spin { output.wallets == [second.metaId] })
        XCTAssertEqual(services.updates, 1)
    }

    func testWireframeReplacesEveryWalletDestinationAndLeavesUnavailableSwapStable() {
        let view = CovDTabViewSpy()
        let wallet = CovDFixtures.wallet(substrate: false)
        let wireframe = MainTabBarWireframe()
        wireframe.reloadWalletDependentViews(on: view, wallet: wallet)
        XCTAssertEqual(view.replacements.map { $0.0 }, [0, 1, 2, 3])
        XCTAssertEqual(view.replacements.map { $0.1.tabBarItem.title },
                       [MainTabBarDestination.portfolio, .defi, .polkaswap, .crossChain].map { Optional($0.title) })
        wireframe.reloadPolkaswapViewIfUnavailable(on: view, wallet: wallet)
        XCTAssertEqual(view.replacements.count, 4)
        view.isPolkaswapUnavailable = false
        wireframe.reloadPolkaswapViewIfUnavailable(on: view, wallet: wallet)
        wireframe.reloadWalletDependentViews(on: nil, wallet: wallet)
        XCTAssertEqual(view.replacements.count, 4)
    }
}
