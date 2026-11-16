import XCTest
import UIKit
import Kingfisher
import SoraFoundation
import SSFModels
import FearlessWalletConnect
@testable import fearless

/// Lane-J WalletConnect fixtures: an English localization, an EVM chain, sessions, requests and signing requests.
enum CovJWcFixture {
    static let locale = Locale(identifier: "en")
    static var languages: [String]? { locale.rLanguages }

    static func localization() throws -> LocalizationManager {
        try XCTUnwrap(LocalizationManager(localization: "en"))
    }

    static func evmChain(id: String = "1", name: String = "Ethereum") -> ChainModel {
        let chain = ChainModel(
            rank: 1, disabled: false, chainId: id, parentId: nil, paraId: nil, name: name, xcm: nil, nodes: [],
            addressPrefix: 0, types: nil, icon: nil, options: [.ethereumBased], externalApi: nil, selectedNode: nil,
            customNodes: nil, iosMinAppVersion: nil, identityChain: nil
        )
        chain.assets = [CovJFixture.asset(id: "eth-\(id)", symbol: "ETH", precision: 18)]
        return chain
    }

    static func blockchain(_ reference: String = "eip155:1") throws -> Blockchain {
        try XCTUnwrap(Blockchain(reference))
    }

    static func metadata(name: String = "Uniswap", url: String = "https://app.uniswap.invalid", icons: [String] = []) -> AppMetadata {
        AppMetadata(name: name, description: "Lane J dApp", url: url, icons: icons)
    }

    static func session(topic: String = "wc-topic", name: String = "Uniswap", url: String = "https://app.uniswap.invalid") -> Session {
        Session(
            topic: topic, pairingTopic: "pairing-\(topic)", peer: metadata(name: name, url: url), requiredNamespaces: [:],
            optionalNamespaces: nil, namespaces: [:], sessionProperties: nil, expiryDate: Date(timeIntervalSince1970: 1_900_000_000)
        )
    }

    static func proposal(
        required: [String: ProposalNamespace] = [:],
        optional: [String: ProposalNamespace]? = nil,
        name: String = "Uniswap"
    ) -> Session.Proposal {
        Session.Proposal(
            id: 42, pairingTopic: "pairing", proposer: metadata(name: name), requiredNamespaces: required,
            optionalNamespaces: optional, sessionProperties: nil, expiryDate: Date(timeIntervalSince1970: 1_900_000_000)
        )
    }

    static func request(method: WalletConnectMethod = .ethereumPersonalSign, topic: String = "wc-topic") throws -> Request {
        Request(topic: topic, method: method.rawValue, params: AnyCodable(["0x00"]), chainId: try blockchain())
    }

    static func message(_ text: String = "Sign in to Uniswap") -> WalletConnectSigningRequest.Content {
        .ethereumMessage(WalletConnectMessage(bytes: Data(text.utf8)))
    }

    static func signingRequest(
        content: WalletConnectSigningRequest.Content = message(),
        method: WalletConnectMethod = .ethereumPersonalSign,
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount(),
        preview: String = "transaction preview"
    ) throws -> WalletConnectSigningRequest {
        let chain = evmChain()
        return WalletConnectSigningRequest(
            request: try request(method: method),
            method: method,
            chain: chain,
            wallet: wallet,
            account: try XCTUnwrap(wallet.fetch(for: chain.accountRequest())),
            content: content,
            preview: preview,
            rawDetails: .null
        )
    }

    static func inputData(
        _ signingRequest: WalletConnectSigningRequest,
        verification: WalletConnectVerification = .verified
    ) -> WalletConnectConfirmationInputData {
        WalletConnectConfirmationInputData(signingRequest: signingRequest, session: session(), verification: verification)
    }
}

/// Compares colors after resolving them for one trait collection, so catalog colors compare by value.
enum CovJWcColor {
    static func same(_ lhs: UIColor?, _ rhs: UIColor?) -> Bool {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil }
        let traits = UITraitCollection(userInterfaceStyle: .dark)
        return lhs.resolvedColor(with: traits).isEqual(rhs.resolvedColor(with: traits))
    }
}

/// Thread-safe list of recorded calls; async stubs append from background executors.
final class CovJWcCalls<T> {
    private let lock = NSLock()
    private var storage: [T] = []

    func append(_ value: T) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }

    var all: [T] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var count: Int { all.count }
}

/// Records what the WalletConnect modules ask of the service; never touches a relay.
final class CovJWcServiceStub: WalletConnectService {
    let proposalDecisions = CovJWcCalls<WalletConnectProposalDecision>()
    let signDecisions = CovJWcCalls<WalletConnectSignDecision>()
    let disconnected = CovJWcCalls<String>()
    let connected = CovJWcCalls<String>()
    var sessions: [Session] = []
    var failure: Error?
    private(set) var listenerCount = 0
    weak var listener: WalletConnectServiceDelegate?

    func setup() {}
    func throttle() {}

    func set(listener: WalletConnectServiceDelegate) {
        listenerCount += 1
        self.listener = listener
    }

    func connect(uri: String) async throws {
        connected.append(uri)
        if let failure { throw failure }
    }

    func disconnect(topic: String) async throws {
        disconnected.append(topic)
        if let failure { throw failure }
    }

    /// How many pending checks answer "still waiting"; later checks answer that the dApp stopped waiting.
    var pendingLimit = Int.max
    let pendingChecks = CovJWcCalls<Int>()

    func disconnectAll() async throws {}
    func getSessions() -> [Session] { sessions }

    func isPending(request _: Request) async -> Bool {
        pendingChecks.append(1)
        return pendingChecks.count <= pendingLimit
    }

    func legacySessionsNeedingReconnect() -> [WalletConnectLegacySession] { [] }

    func submit(proposalDecision: WalletConnectProposalDecision) async throws {
        proposalDecisions.append(proposalDecision)
        if let failure { throw failure }
    }

    func submit(signDecision: WalletConnectSignDecision) async throws {
        signDecisions.append(signDecision)
        if let failure { throw failure }
    }
}

/// Keeps the balance listeners so a test can deliver balances by hand.
final class CovJWcBalanceAdapterStub: WalletBalanceSubscriptionAdapterProtocol {
    private(set) var walletsListeners: [WalletBalanceSubscriptionListener] = []

    func subscribeWalletBalance(wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}

    func subscribeWalletsBalances(listener: WalletBalanceSubscriptionListener) {
        walletsListeners.append(listener)
    }

    func subscribeChainAssetBalance(wallet _: MetaAccountModel, chainAsset _: ChainAsset, listener _: WalletBalanceSubscriptionListener) {}
    func subscribeChainAssetsBalance(chainAssets _: [ChainAsset], wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}
    func subscribeNetworkManagementBalance(wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}
    func unsubscribe(listener _: WalletBalanceSubscriptionListener) {}
}

final class CovJWcStatisticsStub: AccountStatisticsFetching {
    func subscribeForStatistics(address _: String) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? { nil }
}

/// An icon that records where it was asked to load instead of fetching anything.
final class CovJWcImageStub: ImageViewModelProtocol {
    private(set) var loads: [UIImageView] = []
    private(set) var placeholders: [Placeholder?] = []
    private(set) var cancels = 0

    var lastPlaceholderIsImage: Bool { placeholders.last.flatMap { $0 } is UIImage }

    func loadImage(
        on imageView: UIImageView,
        targetSize _: CGSize,
        animated _: Bool,
        cornerRadius _: CGFloat,
        completionHandler _: ((Result<RetrieveImageResult, KingfisherError>) -> Void)?
    ) {
        loads.append(imageView)
    }

    func loadImage(on imageView: UIImageView, targetSize _: CGSize, animated _: Bool, cornerRadius _: CGFloat) {
        loads.append(imageView)
    }

    func loadImage(on imageView: UIImageView, targetSize _: CGSize, animated _: Bool) {
        loads.append(imageView)
    }

    func loadImage(on imageView: UIImageView, placholder: Placeholder?, targetSize _: CGSize, animated _: Bool) {
        loads.append(imageView)
        placeholders.append(placholder)
    }

    func cancel(on _: UIImageView) {
        cancels += 1
    }
}

final class CovJWcCoordinator: Coordinator {
    private(set) var starts = 0
    func start() { starts += 1 }
}

final class CovJWcCoordinatorTests: XCTestCase {
    func testDefaultCoordinatorKeepsChildrenUniqueAndRemovesOnlyKnownOnes() {
        let parent = DefaultCoordinator()
        let first = CovJWcCoordinator()
        let second = CovJWcCoordinator()
        parent.start()
        parent.removeChildCoordinator(first)
        XCTAssertTrue(parent.childCoordinators.isEmpty)
        parent.addChildCoordinator(first)
        parent.addChildCoordinator(first)
        parent.addChildCoordinator(second)
        XCTAssertEqual(parent.childCoordinators.count, 2)
        parent.removeChildCoordinator(nil)
        parent.removeChildCoordinator(CovJWcCoordinator())
        XCTAssertEqual(parent.childCoordinators.count, 2)
        parent.removeChildCoordinator(first)
        XCTAssertEqual(parent.childCoordinators.count, 1)
        XCTAssertTrue(parent.childCoordinators.first === second)
        XCTAssertEqual(first.starts, 0)
    }

    func testRouterWithoutSceneStaysIdleAndIgnoresPresentAndDismiss() {
        let center = NotificationCenter()
        let lockState = ApplicationLockState(notificationCenter: center)
        let router = WalletConnectCoordinatorRouterImpl(lockState: lockState, notificationCenter: center, windowScene: { nil })
        var completions = 0
        router.setRoot(controller: UIViewController())
        router.present(controller: UIViewController())
        router.dismiss { completions += 1 }
        lockState.lock(with: UIViewController())
        lockState.unlock()
        XCTAssertFalse(router.isBusy)
        XCTAssertNil(router.coveringWindow)
        XCTAssertEqual(completions, 0)
    }

    func testRouterPresentsOnTopOfTheCoveringWindowAndDismissesIt() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let center = NotificationCenter()
        let router = WalletConnectCoordinatorRouterImpl(
            lockState: ApplicationLockState(notificationCenter: center),
            notificationCenter: center,
            windowScene: { scene }
        )
        let root = UIViewController()
        router.setRoot(controller: root)
        let window = try XCTUnwrap(router.coveringWindow)
        defer { window.isHidden = true }
        XCTAssertTrue(router.isBusy)
        XCTAssertEqual(window.windowLevel, UIWindow.Level.alert + 1)
        XCTAssertTrue(CovJWait.until(timeout: 3) { root.viewIfLoaded?.window === window && !root.isBeingPresented })
        let next = UIViewController()
        router.present(controller: next)
        XCTAssertTrue(CovJWait.until(timeout: 3) { root.presentedViewController === next && !next.isBeingPresented })
        var completions = 0
        router.dismiss { completions += 1 }
        XCTAssertTrue(CovJWait.until(timeout: 5) { completions == 1 })
        XCTAssertFalse(router.isBusy)
        XCTAssertTrue(window.isHidden)
    }

    func testDefaultRouterUsesTheActiveWindowScene() {
        let expectsWindow = SceneWindowFinder.activeWindow() != nil
        let router = WalletConnectCoordinatorRouterImpl()
        XCTAssertFalse(router.isBusy)
        let root = UIViewController()
        router.setRoot(controller: root)
        XCTAssertEqual(router.isBusy, expectsWindow)
        let window = router.coveringWindow
        var completions = 0
        if expectsWindow {
            XCTAssertTrue(CovJWait.until(timeout: 3) { root.viewIfLoaded?.window != nil && !root.isBeingPresented })
            router.dismiss { completions += 1 }
            XCTAssertTrue(CovJWait.until(timeout: 5) { completions == 1 })
        } else {
            router.dismiss { completions += 1 }
            XCTAssertEqual(completions, 0)
        }
        window?.isHidden = true
        XCTAssertFalse(router.isBusy)
    }
}
