import XCTest
import UIKit
import SoraFoundation
import SSFModels
import SSFQRService
import FearlessWalletConnect
@testable import fearless

final class CovJWcActiveSessionsViewSpy: UIViewController, WalletConnectActiveSessionsViewInput {
    private(set) var received: [[WalletConnectActiveSessionsViewModel]] = []
    private(set) var starts = 0
    private(set) var stops = 0

    func didReceive(viewModels: [WalletConnectActiveSessionsViewModel]) { received.append(viewModels) }
    func didStartLoading() { starts += 1 }
    func didStopLoading() { stops += 1 }
}

final class CovJWcActiveSessionsInteractorStub: WalletConnectActiveSessionsInteractorInput {
    weak var output: WalletConnectActiveSessionsInteractorOutput?
    let uris = CovJWcCalls<String>()
    var failure: Error?

    func setup(with output: WalletConnectActiveSessionsInteractorOutput) { self.output = output }

    func setupConnection(uri: String) async throws {
        uris.append(uri)
        if let failure { throw failure }
    }
}

final class CovJWcActiveSessionsRouterSpy: CovJSheetSpy, WalletConnectActiveSessionsRouterInput {
    private(set) var shown: [String] = []
    private(set) var scanners: [ScanQRModuleOutput] = []
    private(set) var dismissals = 0

    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
    func showSession(_ session: Session, view _: ControllerBackedProtocol?) { shown.append(session.topic) }
    func showScaner(output: ScanQRModuleOutput, view _: ControllerBackedProtocol?) { scanners.append(output) }
}

final class CovJWcActiveSessionsOutputSpy: WalletConnectActiveSessionsViewOutput {
    private(set) var loads = 0
    private(set) var selected: [IndexPath] = []
    private(set) var backs = 0
    private(set) var filters: [String?] = []
    private(set) var creates = 0

    func didLoad(view _: WalletConnectActiveSessionsViewInput) { loads += 1 }
    func didSelectRowAt(_ indexPath: IndexPath) { selected.append(indexPath) }
    func backButtonDidTapped() { backs += 1 }
    func filterConnection(by text: String?) { filters.append(text) }
    func createNewConnection() { creates += 1 }
}

final class CovJWcActiveSessionsInteractorOutputSpy: WalletConnectActiveSessionsInteractorOutput {
    private(set) var received: [[String]] = []
    func didReceive(sessions: [Session]) { received.append(sessions.map(\.topic)) }
}

final class CovJWcActiveSessionsPresenterTests: XCTestCase {
    private let sessions = [
        CovJWcFixture.session(topic: "uni", name: "Uniswap", url: "https://app.uniswap.invalid"),
        CovJWcFixture.session(topic: "sea", name: "OpenSea", url: "https://opensea.invalid")
    ]

    private func makePresenter(
        interactor: CovJWcActiveSessionsInteractorStub,
        router: CovJWcActiveSessionsRouterSpy
    ) throws -> WalletConnectActiveSessionsPresenter {
        WalletConnectActiveSessionsPresenter(
            viewModelFactory: WalletConnectActiveSessionsViewModelFactoryImpl(),
            interactor: interactor,
            router: router,
            localizationManager: try CovJWcFixture.localization()
        )
    }

    func testLoadsSessionsFiltersByNameAndRoutes() throws {
        let interactor = CovJWcActiveSessionsInteractorStub()
        let router = CovJWcActiveSessionsRouterSpy()
        let presenter = try makePresenter(interactor: interactor, router: router)
        let view = CovJWcActiveSessionsViewSpy()
        presenter.filterConnection(by: "uni")
        presenter.didSelectRowAt(IndexPath(row: 0, section: 0))
        XCTAssertTrue(router.shown.isEmpty, "Nothing to show before the sessions arrive")

        presenter.didLoad(view: view)
        XCTAssertEqual(view.starts, 1)
        XCTAssertTrue(interactor.output === presenter)
        XCTAssertTrue(view.received.isEmpty)

        presenter.didReceive(sessions: sessions)
        XCTAssertEqual(view.stops, 1)
        XCTAssertEqual(view.received.last?.map(\.name), ["Uniswap", "OpenSea"])
        XCTAssertEqual(view.received.last?.map(\.host), ["app.uniswap.invalid", "opensea.invalid"])

        presenter.didSelectRowAt(IndexPath(row: 1, section: 0))
        presenter.didSelectRowAt(IndexPath(row: 7, section: 0))
        XCTAssertEqual(router.shown, ["sea"])

        presenter.filterConnection(by: "SEA")
        XCTAssertEqual(view.received.last?.map(\.name), ["OpenSea"])
        presenter.filterConnection(by: "")
        XCTAssertEqual(view.received.last?.map(\.name), ["Uniswap", "OpenSea"])
        presenter.filterConnection(by: nil)
        XCTAssertEqual(view.received.last?.count, 0)
        XCTAssertEqual(view.stops, 1, "Filtering does not touch the loading state")

        presenter.backButtonDidTapped()
        presenter.createNewConnection()
        presenter.applyLocalization()
        XCTAssertEqual(router.dismissals, 1)
        XCTAssertEqual(router.scanners.count, 1)
        XCTAssertTrue(router.scanners.first === presenter)
    }

    func testScannedPairingLinksConnectAndFailuresAreShown() throws {
        let interactor = CovJWcActiveSessionsInteractorStub()
        let router = CovJWcActiveSessionsRouterSpy()
        let presenter = try makePresenter(interactor: interactor, router: router)
        let view = CovJWcActiveSessionsViewSpy()
        presenter.didLoad(view: view)

        let sora = SoraQRInfo(address: "cnVko", rawPublicKey: Data(repeating: 1, count: 32), username: "lane-j", assetId: "xor", amount: nil)
        presenter.didFinishWith(scanType: .qrInfo(.sora(sora)))
        presenter.didFinishWith(scanType: .walletConnect("wc:topic@2?relay-protocol=irn&symKey=00"))
        XCTAssertTrue(CovJWait.until(timeout: 5) { interactor.uris.count == 1 })
        XCTAssertEqual(interactor.uris.all, ["wc:topic@2?relay-protocol=irn&symKey=00"])
        CovJWait.drain()
        XCTAssertTrue(router.errors.isEmpty)

        interactor.failure = CovJError("pairing expired")
        presenter.didFinishWith(scanType: .walletConnect("wc:expired@2"))
        XCTAssertTrue(CovJWait.until(timeout: 5) { router.errors.count == 1 })
        XCTAssertEqual(router.errors.first as? CovJError, CovJError("pairing expired"))
        XCTAssertEqual(interactor.uris.count, 2)
    }
}

final class CovJWcActiveSessionsModuleTests: XCTestCase {
    private var languages: [String]? { CovJWcFixture.languages }

    func testInteractorReadsSessionsListensForChangesAndConnects() async throws {
        let service = CovJWcServiceStub()
        service.sessions = [CovJWcFixture.session(topic: "uni")]
        let interactor = WalletConnectActiveSessionsInteractor(walletConnectService: service)
        let output = CovJWcActiveSessionsInteractorOutputSpy()
        interactor.setup(with: output)
        XCTAssertEqual(output.received, [["uni"]])
        XCTAssertEqual(service.listenerCount, 1)
        XCTAssertTrue(service.listener === interactor)

        interactor.didChange(sessions: [CovJWcFixture.session(topic: "uni"), CovJWcFixture.session(topic: "sea")])
        XCTAssertEqual(output.received, [["uni"], ["uni", "sea"]])

        try await interactor.setupConnection(uri: "wc:new@2")
        XCTAssertEqual(service.connected.all, ["wc:new@2"])
        service.failure = CovJError("relay")
        do {
            try await interactor.setupConnection(uri: "wc:bad@2")
            XCTFail("A pairing failure reaches the presenter")
        } catch {
            XCTAssertEqual(error as? CovJError, CovJError("relay"))
        }
    }

    func testViewModelFactoryTakesNameHostAndFirstIcon() throws {
        let withIcon = Session(
            topic: "icon", pairingTopic: "pairing", peer: CovJWcFixture.metadata(name: "Icon dApp", icons: ["https://cdn.invalid/a.png", "b"]),
            requiredNamespaces: [:], optionalNamespaces: nil, namespaces: [:], sessionProperties: nil, expiryDate: Date()
        )
        let models = WalletConnectActiveSessionsViewModelFactoryImpl().createViewModel(from: [
            withIcon,
            CovJWcFixture.session(topic: "plain", name: "No host", url: "")
        ])
        XCTAssertEqual(models.map(\.name), ["Icon dApp", "No host"])
        XCTAssertEqual(models[0].host, "app.uniswap.invalid")
        XCTAssertNil(models[1].host)
        let icon = try XCTUnwrap(models[0].icon as? RemoteImageViewModel)
        XCTAssertEqual(icon.url.absoluteString, "https://cdn.invalid/a.png")
        XCTAssertNil(models[1].icon)
        XCTAssertTrue(WalletConnectActiveSessionsViewModelFactoryImpl().createViewModel(from: []).isEmpty)
    }

    func testControllerShowsSessionsAndForwardsActions() throws {
        let output = CovJWcActiveSessionsOutputSpy()
        let controller = WalletConnectActiveSessionsViewController(output: output, localizationManager: try CovJWcFixture.localization())
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let layout = controller.rootView
        let table = layout.tableView
        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(layout.navigationBar.titleLabel.text, R.string.localizable.commonConnections(preferredLanguages: languages))
        XCTAssertEqual(layout.searchView.textField.placeholder, R.string.localizable.searchByConnection(preferredLanguages: languages))
        XCTAssertEqual(
            layout.createNewConnectionButton.imageWithTitleView?.title,
            R.string.localizable.createNewConnection(preferredLanguages: languages)
        )
        XCTAssertEqual(table.rowHeight, 51)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)

        let icon = CovJWcImageStub()
        controller.didReceive(viewModels: [
            WalletConnectActiveSessionsViewModel(name: "Uniswap", host: "app.uniswap.invalid", icon: icon),
            WalletConnectActiveSessionsViewModel(name: "OpenSea", host: nil, icon: nil)
        ])
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        let first = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? WalletConnectActiveSessionsTableCell)
        controller.tableView(table, willDisplay: first, forRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(first.nameLabel.text, "Uniswap")
        XCTAssertEqual(first.hostLabel.text, "app.uniswap.invalid")
        XCTAssertTrue(icon.loads.last === first.iconImageView)
        XCTAssertTrue(icon.lastPlaceholderIsImage)
        let second = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 1, section: 0)) as? WalletConnectActiveSessionsTableCell)
        controller.tableView(table, willDisplay: second, forRowAt: IndexPath(row: 1, section: 0))
        controller.tableView(table, willDisplay: UITableViewCell(), forRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(second.nameLabel.text, "OpenSea")
        XCTAssertNil(second.hostLabel.text)
        XCTAssertNotNil(second.arrowImageView.image)
        XCTAssertEqual(second.selectionStyle, .none)

        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        layout.navigationBar.backButton.sendActions(for: .touchUpInside)
        layout.searchView.onTextDidChanged?("uni")
        layout.createNewConnectionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.selected, [IndexPath(row: 1, section: 0)])
        XCTAssertEqual(output.backs, 1)
        XCTAssertEqual(output.filters, ["uni"])
        XCTAssertEqual(output.creates, 1)

        controller.applyLocalization()
        layout.layoutIfNeeded()
        XCTAssertEqual(layout.locale.identifier, "en")
    }

    func testAssemblyBuildsTheConnectionsScreen() throws {
        let module = try XCTUnwrap(WalletConnectActiveSessionsAssembly.configureModule())
        let controller = try XCTUnwrap(module.view.controller as? WalletConnectActiveSessionsViewController)
        XCTAssertTrue(module.input is WalletConnectActiveSessionsPresenter)
        let expected = WalletConnectServiceImpl.shared.getSessions().count
        XCTAssertEqual(controller.tableView(controller.rootView.tableView, numberOfRowsInSection: 0), expected)
    }

    func testRouterOpensTheSessionDetails() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        WalletConnectActiveSessionsRouter().showSession(CovJWcFixture.session(topic: "details", name: "Details", url: ""), view: host)
        XCTAssertTrue(host.presented is WalletConnectProposalViewController)
    }
}
