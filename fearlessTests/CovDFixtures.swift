import BigInt
import Foundation
import SoraKeystore
import SSFModels
import UIKit
import XCTest

@testable import fearless

/// Shared fixtures for lane D coverage tests (MainTabBar DeFi, LiquidityPools, PolkaswapFlow).
enum CovDFixtures {
    static let kusdAssetId = PolkamarktConstants.collateralAssetId
    static let xorAssetId = PolkamarktConstants.feeAssetId
    static let valAssetId = "0x0200040000000000000000000000000000000000000000000000000000000000"
    static let pswapAssetId = "0x0200050000000000000000000000000000000000000000000000000000000000"

    static func wallet(substrate: Bool = true, name: String = "CovD wallet") -> MetaAccountModel {
        MetaAccountModel(
            metaId: UUID().uuidString,
            name: name,
            substrateAccountId: substrate ? Data(repeating: 7, count: 32) : nil,
            substrateCryptoType: 0,
            substratePublicKey: substrate ? Data(repeating: 9, count: 32) : nil,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            assetKeysOrder: nil,
            canExportEthereumMnemonic: true,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: true,
            favouriteChainIds: []
        )
    }

    static func asset(
        id: String,
        symbol: String,
        precision: UInt16 = 18,
        currencyId: String? = nil,
        priceId: String? = nil,
        isUtility: Bool = false
    ) -> AssetModel {
        AssetModel(
            id: id,
            name: symbol,
            symbol: symbol,
            precision: precision,
            currencyId: currencyId,
            isUtility: isUtility,
            isNative: isUtility,
            coingeckoPriceId: priceId
        )
    }

    /// A SORA-like chain. `chainId` defaults to a random identifier so nothing reaches the shared registry.
    static func soraChain(
        chainId: String = "covd-sora-\(UUID().uuidString)",
        nodeURL: String? = "wss://sora.invalid/public-ws",
        historyURL: String? = nil,
        assets: [AssetModel]? = nil
    ) -> ChainModel {
        let nodes: Set<ChainNodeModel> = nodeURL.flatMap { URL(string: $0) }.map {
            [ChainNodeModel(url: $0, name: "covd node", apikey: nil)]
        } ?? []
        let history = historyURL.flatMap { URL(string: $0) }.flatMap {
            ChainModel.BlockExplorer(type: "sora", url: $0)
        }
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: "SORA",
            xcm: nil,
            nodes: nodes,
            addressPrefix: 69,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: history.map { ChainModel.ExternalApiSet(history: $0) },
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        let defaultAssets = [
            asset(id: "xor", symbol: "XOR", currencyId: xorAssetId, isUtility: true),
            asset(id: "kusd", symbol: "KUSD", currencyId: kusdAssetId),
            asset(id: "val", symbol: "VAL", currencyId: valAssetId)
        ]
        (assets ?? defaultAssets).forEach { chain.assets.insert($0) }
        return chain
    }

    static func chainAsset(_ chain: ChainModel, currencyId: String) -> ChainAsset? {
        chain.chainAssets.first { $0.asset.currencyId == currencyId }
    }

    static func price(_ value: String, priceId: String, currencyId: String = "usd") -> PriceData {
        PriceData(currencyId: currencyId, priceId: priceId, price: value, fiatDayChange: nil, coingeckoPriceId: nil)
    }

    @discardableResult
    static func host(_ controller: UIViewController, size: CGSize = CGSize(width: 390, height: 844)) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        window.layoutIfNeeded()
        return window
    }

    static func tearDown(_ window: UIWindow?) {
        window?.rootViewController?.presentedViewController?.dismiss(animated: false)
        window?.isHidden = true
        window?.rootViewController = nil
    }

    /// Spins the main run loop until `condition` holds or `timeout` passes; returns the final condition.
    @discardableResult
    static func spin(timeout: TimeInterval = 3, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if condition() { return true }
            if Date() > deadline { return condition() }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    static func cellTexts(_ tableView: UITableView, section: Int) -> [(String?, String?)] {
        let dataSource = tableView.dataSource
        let rows = dataSource?.tableView(tableView, numberOfRowsInSection: section) ?? 0
        return (0 ..< rows).map { row in
            let cell = dataSource?.tableView(tableView, cellForRowAt: IndexPath(row: row, section: section))
            let config = cell?.contentConfiguration as? UIListContentConfiguration
            return (config?.text, config?.secondaryText)
        }
    }

    static func findTableView(in view: UIView) -> UITableView? {
        if let table = view as? UITableView { return table }
        for subview in view.subviews {
            if let table = findTableView(in: subview) { return table }
        }
        return nil
    }

    static func allLabels(in view: UIView) -> [UILabel] {
        var result: [UILabel] = []
        if let label = view as? UILabel { result.append(label) }
        view.subviews.forEach { result.append(contentsOf: allLabels(in: $0)) }
        return result
    }

    static func allButtons(in view: UIView) -> [UIButton] {
        var result: [UIButton] = []
        if let button = view as? UIButton { result.append(button) }
        view.subviews.forEach { result.append(contentsOf: allButtons(in: $0)) }
        return result
    }
}

/// Answers JSON-RPC requests by method name and GraphQL requests by a query keyword.
final class CovDRoutingTransport: PolkamarktHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var rpcResults: [String: Any] = [:]
    private var rpcErrors: [String: String] = [:]
    private var graphQL: [(String, Any)] = []
    private(set) var methods: [String] = []
    private(set) var queries: [String] = []

    func setRPC(_ method: String, result: Any) {
        lock.lock(); rpcResults[method] = result; lock.unlock()
    }

    func setRPCError(_ method: String, message: String) {
        lock.lock(); rpcErrors[method] = message; lock.unlock()
    }

    func setGraphQL(_ keyword: String, response: Any) {
        lock.lock(); graphQL.append((keyword, response)); lock.unlock()
    }

    func recordedMethods() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return methods
    }

    func post(_ body: Data, to _: URL) async throws -> Data {
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any] ?? [:]
        lock.lock()
        defer { lock.unlock() }
        if let method = object["method"] as? String {
            methods.append(method)
            if let message = rpcErrors[method] {
                return try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": 1, "error": ["message": message]])
            }
            guard let result = rpcResults[method] else { throw PolkamarktServiceError.invalidResponse }
            return try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": 1, "result": result])
        }
        let query = object["query"] as? String ?? ""
        queries.append(query)
        guard let match = graphQL.first(where: { query.contains($0.0) }) else {
            throw PolkamarktServiceError.invalidResponse
        }
        return try JSONSerialization.data(withJSONObject: match.1)
    }
}

final class CovDAccountInfoServiceStub: AccountInfoRemoteService {
    var infos: [ChainAssetId: AccountInfo?] = [:]
    var error: Error?
    private(set) var fetchCount = 0

    func fetchAccountInfos(for _: ChainModel, wallet _: MetaAccountModel) async throws -> [ChainAssetId: AccountInfo?] {
        fetchCount += 1
        if let error { throw error }
        return infos
    }

    func fetchAccountInfo(for chainAsset: ChainAsset, wallet _: MetaAccountModel) async throws -> AccountInfo? {
        if let error { throw error }
        return infos[chainAsset.chainAssetId] ?? nil
    }
}

final class CovDRegistryStub: ChainRegistryProtocolStub, @unchecked Sendable {
    var chains: [ChainModel.Id: ChainModel] = [:]
    var runtime: RuntimeProviderProtocol?
    var connection: ChainConnection?

    override var availableChains: [ChainModel] { Array(chains.values) }

    override func getChain(for chainId: ChainModel.Id) -> ChainModel? { chains[chainId] }

    override func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? { runtime }

    override func getConnection(for _: ChainModel.Id) -> ChainConnection? { connection }
}

final class CovDSubmissionAuthorizerStub: SubmissionAuthorizing {
    var allow = true
    private(set) var requests = 0

    func authorizeSubmission(from _: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
        requests += 1
        completion(allow)
    }
}

enum CovDTestError: LocalizedError, Equatable {
    case offline

    var errorDescription: String? { "CovD offline" }
}
