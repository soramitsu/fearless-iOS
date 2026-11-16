import BigInt
import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

/// Shared NFT fixtures and test doubles for the CovHNft* suites.
enum CovHNftFixtures {
    static let thumbnailMissingFile = "file:///nonexistent/covh-nft-missing.png"

    static func utilityAsset(symbol: String = "CVH") -> AssetModel {
        AssetModel(
            id: "covh-nft-utility-\(symbol)",
            name: symbol,
            symbol: symbol,
            precision: 12,
            isUtility: true,
            isNative: true
        )
    }

    static func chain(
        name: String = "CovH Chain",
        ethereum: Bool = false,
        utility: Bool = true,
        historyType: String? = nil
    ) -> ChainModel {
        let node = ChainNodeModel(url: URL(string: "wss://node.invalid")!, name: "node", apikey: nil)
        let history = historyType.flatMap {
            ChainModel.BlockExplorer(type: $0, url: URL(string: "https://history.invalid/api")!)
        }
        let externalApi = history.map {
            ChainModel.ExternalApiSet(staking: nil, history: $0, crowdloans: nil, explorers: nil, pricing: nil)
        }
        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: "covh-nft-\(UUID().uuidString.lowercased())",
            parentId: nil,
            paraId: nil,
            name: name,
            assets: utility ? [utilityAsset()] : [],
            xcm: nil,
            nodes: [node],
            addressPrefix: 42,
            types: nil,
            icon: nil,
            options: ethereum ? [.ethereum] : nil,
            externalApi: externalApi,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    static func wallet() -> MetaAccountModel {
        AccountGenerator.generateMetaAccount()
    }

    static func walletWithoutAccounts() -> MetaAccountModel {
        MetaAccountModel(
            metaId: UUID().uuidString,
            name: "No accounts",
            substrateAccountId: nil,
            substrateCryptoType: 0,
            substratePublicKey: nil,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            assetKeysOrder: nil,
            canExportEthereumMnemonic: false,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: true,
            favouriteChainIds: []
        )
    }

    static func address(of wallet: MetaAccountModel, on chain: ChainModel) -> String? {
        wallet.fetch(for: chain.accountRequest())?.toAddress()
    }

    static func collection(
        chain: ChainModel,
        address: String? = "0xcollection",
        name: String? = "CovH Collection",
        creator: String? = "creator-address",
        desc: String? = "Collection description",
        nfts: [NFT]? = nil,
        availableNfts: [NFT]? = nil,
        totalSupply: String? = nil
    ) -> NFTCollection {
        NFTCollection(
            address: address,
            numberOfTokens: nil,
            isSpam: false,
            title: nil,
            name: name,
            creator: creator,
            price: nil,
            media: nil,
            tokenType: .erc721,
            desc: desc,
            opensea: nil,
            chain: chain,
            totalSupply: totalSupply,
            nfts: nfts,
            availableNfts: availableNfts
        )
    }

    static func nft(
        chain: ChainModel,
        tokenId: String? = "0x0a",
        title: String? = "CovH Token",
        description: String? = "Token description",
        contract: String? = "0xcollection",
        thumbnail: String? = nil,
        tokenType: NFTTokenType? = .erc721,
        collectionName: String? = "CovH Collection",
        collection: NFTCollection? = nil
    ) -> NFT {
        NFT(
            chain: chain,
            tokenId: tokenId,
            title: title,
            description: description,
            smartContract: contract,
            metadata: nil,
            mediaThumbnail: thumbnail,
            media: nil,
            tokenType: tokenType,
            collectionName: collectionName,
            collection: collection
        )
    }

    static func pngFileURL() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("covh-nft-\(UUID().uuidString).png")
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: url)
        return url
    }

    static func messages(_ sources: [Any]) -> [String] {
        sources.compactMap { ($0 as? TextSharingSource)?.message }
    }
}

enum CovHNftWait {
    static func until(_ timeout: TimeInterval = 3, _ predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    static func spin(_ interval: TimeInterval) {
        let deadline = Date().addingTimeInterval(interval)
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}

enum CovHNftViews {
    static func texts(in view: UIView) -> [String] {
        var result: [String] = []
        if let label = view as? UILabel, let text = label.text, !text.isEmpty {
            result.append(text)
        }
        if let field = view as? UITextField, let text = field.text, !text.isEmpty {
            result.append(text)
        }
        for subview in view.subviews {
            result.append(contentsOf: texts(in: subview))
        }
        return result
    }

    static func all<T: UIView>(_: T.Type, in view: UIView) -> [T] {
        var result: [T] = []
        if let match = view as? T {
            result.append(match)
        }
        for subview in view.subviews {
            result.append(contentsOf: all(T.self, in: subview))
        }
        return result
    }

    @discardableResult
    static func host(_ controller: UIViewController) -> UIWindow {
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        }
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        return window
    }
}

/// A view controller that records presentations and dismissals instead of animating them.
class CovHNftHostController: UIViewController, ControllerBackedProtocol {
    private(set) var presented: [UIViewController] = []
    private(set) var dismissCount = 0

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        presented.append(viewControllerToPresent)
        completion?()
    }

    override func dismiss(animated _: Bool, completion: (() -> Void)? = nil) {
        dismissCount += 1
        completion?()
    }
}

final class CovHNftNavigationSpy: UINavigationController {
    var presentingOverride: UIViewController?
    private(set) var presented: [UIViewController] = []
    private(set) var pushed: [UIViewController] = []
    private(set) var popCount = 0
    private(set) var dismissCount = 0

    override var presentingViewController: UIViewController? {
        presentingOverride ?? super.presentingViewController
    }

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        presented.append(viewControllerToPresent)
        completion?()
    }

    override func dismiss(animated _: Bool, completion: (() -> Void)? = nil) {
        dismissCount += 1
        completion?()
    }

    override func pushViewController(_ viewController: UIViewController, animated _: Bool) {
        // `init(rootViewController:)` pushes the root; only record pushes made by the code under test.
        if !viewControllers.isEmpty {
            pushed.append(viewController)
        }
        super.pushViewController(viewController, animated: false)
    }

    override func popViewController(animated _: Bool) -> UIViewController? {
        popCount += 1
        return super.popViewController(animated: false)
    }
}

final class CovHNftEventCenterSpy: EventCenterProtocol {
    private(set) var observers: [EventVisitorProtocol] = []
    private(set) var notified: [EventProtocol] = []

    func notify(with event: EventProtocol) {
        notified.append(event)
    }

    func add(observer: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {
        observers.append(observer)
    }

    func remove(observer _: EventVisitorProtocol) {}
}

enum CovHNftError: Error {
    case failed
}

final class CovHNftFetchingStub: NFTFetchingServiceProtocol {
    private let lock = NSLock()
    var collections: Result<[NFTCollection], Error> = .success([])
    var nfts: Result<[NFT], Error> = .success([])
    var batch: Result<NFTBatch, Error> = .success(NFTBatch(nfts: [], nextTokenId: nil))
    var owners: Result<[String], Error> = .success([])
    private var storedExcludes: [[String]] = []
    private var storedChains: [[ChainModel]?] = []
    private var storedBatchRequests: [(String, String?)] = []
    private var storedOwnerRequests: [(String, String)] = []

    var excludes: [[String]] { lock.lock(); defer { lock.unlock() }; return storedExcludes }
    var chainRequests: [[ChainModel]?] { lock.lock(); defer { lock.unlock() }; return storedChains }
    var batchRequests: [(String, String?)] { lock.lock(); defer { lock.unlock() }; return storedBatchRequests }
    var ownerRequests: [(String, String)] { lock.lock(); defer { lock.unlock() }; return storedOwnerRequests }

    func fetchCollections(for _: MetaAccountModel, excludeFilters _: [NftCollectionFilter], chains _: [ChainModel]?) async throws -> [NFTCollection] {
        try collections.get()
    }

    func fetchNfts(for _: MetaAccountModel, excludeFilters: [NftCollectionFilter], chains: [ChainModel]?) async throws -> [NFT] {
        lock.lock()
        storedExcludes.append(excludeFilters.map(\.id))
        storedChains.append(chains)
        lock.unlock()
        return try nfts.get()
    }

    func fetchCollectionNfts(collectionAddress: String, chain _: ChainModel, nextId: String?) async throws -> NFTBatch {
        lock.lock()
        storedBatchRequests.append((collectionAddress, nextId))
        lock.unlock()
        return try batch.get()
    }

    func fetchOwners(for address: String, tokenId: String, chain _: ChainModel) async throws -> [String] {
        lock.lock()
        storedOwnerRequests.append((address, tokenId))
        lock.unlock()
        return try owners.get()
    }
}

final class CovHNftTransferStub: NftTransferService {
    private let lock = NSLock()
    var fee: Result<BigUInt, Error> = .success(BigUInt(1_000_000_000_000))
    var submitResult: Result<String, Error> = .success("0xhash")
    private var storedEstimates: [String] = []
    private var storedSubmits: [String] = []
    private var storedListeners: [TransferFeeEstimationListener] = []

    var estimates: [String] { lock.lock(); defer { lock.unlock() }; return storedEstimates }
    var submits: [String] { lock.lock(); defer { lock.unlock() }; return storedSubmits }
    var listeners: [TransferFeeEstimationListener] { lock.lock(); defer { lock.unlock() }; return storedListeners }

    func estimateFee(for transfer: NftTransfer) async throws -> BigUInt {
        lock.lock()
        storedEstimates.append(transfer.receiver)
        lock.unlock()
        return try fee.get()
    }

    func submit(transfer: NftTransfer) async throws -> String {
        lock.lock()
        storedSubmits.append(transfer.receiver)
        lock.unlock()
        return try submitResult.get()
    }

    func subscribeForFee(transfer _: NftTransfer, listener: TransferFeeEstimationListener) {
        lock.lock()
        storedListeners.append(listener)
        lock.unlock()
    }
}

final class CovHNftAccountInfoAdapterSpy: AccountInfoSubscriptionAdapterProtocol {
    private(set) var subscriptions: [(ChainAsset, AccountId)] = []
    private(set) weak var handler: AccountInfoSubscriptionAdapterHandler?

    func subscribe(
        chainAsset: ChainAsset,
        accountId: AccountId,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {
        subscriptions.append((chainAsset, accountId))
        self.handler = handler
    }

    func subscribe(
        chainsAssets _: [ChainAsset],
        handler _: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {}

    func reset() {}
    func unsubscribe(chainAsset _: ChainAsset) {}
    func update(wallet _: MetaAccountModel) {}
}

final class CovHNftFixturesTests: XCTestCase {
    func testFixturesProduceAddressesOnlyForWalletsWithKeys() {
        let chain = CovHNftFixtures.chain()
        let ethereumChain = CovHNftFixtures.chain(ethereum: true)
        let wallet = CovHNftFixtures.wallet()
        let empty = CovHNftFixtures.walletWithoutAccounts()

        XCTAssertNotNil(CovHNftFixtures.address(of: wallet, on: chain))
        XCTAssertNotNil(CovHNftFixtures.address(of: wallet, on: ethereumChain))
        XCTAssertNil(CovHNftFixtures.address(of: empty, on: chain))
        XCTAssertNil(CovHNftFixtures.address(of: empty, on: ethereumChain))
        XCTAssertEqual(chain.utilityChainAssets().count, 1)
        XCTAssertTrue(CovHNftFixtures.chain(utility: false).utilityChainAssets().isEmpty)
        XCTAssertEqual(ethereumChain.chainBaseType, .ethereum)
    }
}
