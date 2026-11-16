import FearlessWalletConnect
import SoraFoundation
import UIKit
import XCTest
@testable import fearless

/// Tapping a row of the active sessions list opens the session that row shows. After a search the list shows only
/// the matching sessions, but the presenter looked the tapped row up in the unfiltered list and opened another one.
final class WalletConnectActiveSessionsSelectionTests: XCTestCase {
    func testTappingARowAfterASearchOpensTheSessionThatRowShows() throws {
        let context = makeContext(peers: ["Alpha Swap", "Beta Bridge", "Gamma Lend"])

        context.presenter.filterConnection(by: "gamma")
        XCTAssertEqual(context.view.shownNames.last, ["Gamma Lend"])
        context.presenter.didSelectRowAt(IndexPath(row: 0, section: 0))

        XCTAssertEqual(context.router.shownTopics, ["topic-Gamma Lend"])
    }

    func testClearingTheSearchMapsRowsToEverySessionAgain() throws {
        let context = makeContext(peers: ["Alpha Swap", "Beta Bridge", "Gamma Lend"])

        context.presenter.filterConnection(by: "beta")
        context.presenter.filterConnection(by: "")
        context.presenter.didSelectRowAt(IndexPath(row: 2, section: 0))

        XCTAssertEqual(context.view.shownNames.last, ["Alpha Swap", "Beta Bridge", "Gamma Lend"])
        XCTAssertEqual(context.router.shownTopics, ["topic-Gamma Lend"])
    }

    func testARowPastTheFilteredListOpensNothing() throws {
        let context = makeContext(peers: ["Alpha Swap", "Beta Bridge"])

        context.presenter.filterConnection(by: "alpha")
        context.presenter.didSelectRowAt(IndexPath(row: 1, section: 0))

        XCTAssertEqual(context.router.shownTopics, [])
    }

    // MARK: - Fixtures

    private struct Context {
        let presenter: WalletConnectActiveSessionsPresenter
        let router: ActiveSessionsRouterSpy
        let view: ActiveSessionsViewSpy
    }

    private func makeContext(peers: [String]) -> Context {
        let router = ActiveSessionsRouterSpy()
        let view = ActiveSessionsViewSpy()
        let presenter = WalletConnectActiveSessionsPresenter(
            viewModelFactory: WalletConnectActiveSessionsViewModelFactoryImpl(),
            interactor: ActiveSessionsInteractorStub(),
            router: router,
            localizationManager: LocalizationManager.shared
        )
        presenter.didLoad(view: view)
        presenter.didReceive(sessions: peers.map(Self.session(peer:)))
        return Context(presenter: presenter, router: router, view: view)
    }

    private static func session(peer: String) -> Session {
        Session(
            topic: "topic-\(peer)",
            pairingTopic: "pairing-\(peer)",
            peer: AppMetadata(name: peer, description: "", url: "https://example.com", icons: []),
            requiredNamespaces: [:],
            optionalNamespaces: nil,
            namespaces: [:],
            sessionProperties: nil,
            expiryDate: Date(timeIntervalSinceNow: 3600)
        )
    }
}

private final class ActiveSessionsInteractorStub: WalletConnectActiveSessionsInteractorInput {
    func setup(with _: WalletConnectActiveSessionsInteractorOutput) {}
    func setupConnection(uri _: String) async throws {}
}

private final class ActiveSessionsRouterSpy: WalletConnectActiveSessionsRouterInput {
    private(set) var shownTopics: [String] = []

    func showSession(_ session: Session, view _: ControllerBackedProtocol?) {
        shownTopics.append(session.topic)
    }

    func showScaner(output _: ScanQRModuleOutput, view _: ControllerBackedProtocol?) {}
}

private final class ActiveSessionsViewSpy: UIViewController, WalletConnectActiveSessionsViewInput {
    private(set) var shownNames: [[String]] = []

    var loadableContentView: UIView { view }
    var shouldDisableInteractionWhenLoading: Bool { false }

    func didReceive(viewModels: [WalletConnectActiveSessionsViewModel]) {
        shownNames.append(viewModels.map(\.name))
    }

    func didStartLoading() {}
    func didStopLoading() {}
}
