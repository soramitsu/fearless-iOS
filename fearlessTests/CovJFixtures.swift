import XCTest
import UIKit
import SSFModels
import RobinHood
@testable import fearless

/// Shared lane-J fixtures: chains, assets, a hosted navigation stack that routers can present from, and a sheet spy.
enum CovJFixture {
    static let locale = Locale(identifier: "en_US")

    static func node(_ name: String) -> ChainNodeModel {
        let host = String(name.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" })
        let url = URL(string: "wss://\(host).invalid") ?? URL(fileURLWithPath: "/dev/null")
        return ChainNodeModel(url: url, name: name, apikey: nil)
    }

    static func chain(
        id: String = UUID().uuidString,
        name: String = "Testnet",
        nodeCount: Int = 1,
        icon: URL? = URL(string: "https://example.invalid/icon.svg"),
        options: [ChainOptions]? = nil,
        assets: [AssetModel] = [],
        addressPrefix: UInt16 = 42
    ) -> ChainModel {
        let nodes = Set((0 ..< nodeCount).map { node("\(name.lowercased())-\($0)") })
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: id,
            parentId: nil,
            paraId: nil,
            name: name,
            xcm: nil,
            nodes: nodes,
            addressPrefix: addressPrefix,
            types: nil,
            icon: icon,
            options: options,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        chain.assets = Set(assets)
        return chain
    }

    static func asset(
        id: String = "asset",
        symbol: String = "TST",
        precision: UInt16 = 12,
        isUtility: Bool = true,
        icon: URL? = nil,
        priceId: String? = nil
    ) -> AssetModel {
        AssetModel(
            id: id,
            name: symbol.uppercased(),
            symbol: symbol,
            precision: precision,
            icon: icon,
            currencyId: nil,
            existentialDeposit: nil,
            color: nil,
            isUtility: isUtility,
            isNative: isUtility,
            staking: nil,
            purchaseProviders: nil,
            type: nil,
            ethereumType: nil,
            priceProvider: nil,
            coingeckoPriceId: priceId
        )
    }

    static func chainAsset(chainName: String = "Testnet", symbol: String = "TST", nodeCount: Int = 1) -> ChainAsset {
        let asset = asset(id: "\(chainName)-\(symbol)", symbol: symbol)
        let chain = chain(name: chainName, nodeCount: nodeCount, assets: [asset])
        return ChainAsset(chain: chain, asset: asset)
    }
}

/// A `ControllerBackedProtocol` view backed by a real controller inside a navigation controller in a visible window.
final class CovJHostedView: ControllerBackedProtocol {
    let controller: UIViewController
    let navigation: UINavigationController
    let window: UIWindow

    var isSetup: Bool { true }

    init(controller: UIViewController = UIViewController()) throws {
        self.controller = controller
        navigation = UINavigationController(rootViewController: controller)
        window = try CovJViewFixture.host(navigation)
    }

    var presented: UIViewController? { controller.presentedViewController ?? navigation.presentedViewController }
    var top: UIViewController? { navigation.viewControllers.last }

    func close() {
        controller.presentedViewController?.dismiss(animated: false)
        navigation.presentedViewController?.dismiss(animated: false)
        window.isHidden = true
    }
}

/// Records sheet alerts and errors instead of presenting them.
class CovJSheetSpy: SheetAlertPresentable {
    var sheets: [SheetAlertPresentableViewModel] = []
    var errors: [Error] = []
    var infos: [(String, String?)] = []

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheets.append(viewModel)
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return true
    }

    func presentInfo(message: String?, title: String, from _: ControllerBackedProtocol?) {
        infos.append((title, message))
    }
}

/// Thread-safe in-memory RobinHood repository. Set `failure` to make every operation fail with that error.
final class CovJMemoryRepository<T: RobinHood.Identifiable>: DataProviderRepositoryProtocol {
    typealias Model = T

    private let lock = NSLock()
    private var storage: [String: T]
    private var order: [String]
    var failure: Error?
    private(set) var saveCount = 0

    init(_ items: [T] = []) {
        storage = Dictionary(items.map { ($0.identifier, $0) }, uniquingKeysWith: { _, new in new })
        order = items.map(\.identifier)
    }

    var items: [T] {
        lock.lock()
        defer { lock.unlock() }
        return order.compactMap { storage[$0] }
    }

    private func make<R>(_ block: @escaping () throws -> R) -> BaseOperation<R> {
        ClosureOperation { [weak self] in
            if let failure = self?.failure { throw failure }
            return try block()
        }
    }

    func fetchOperation(by modelIdsClosure: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        make { [unowned self] in
            let ids = try modelIdsClosure()
            return self.items.filter { ids.contains($0.identifier) }
        }
    }

    func fetchOperation(by modelIdClosure: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<T?> {
        make { [unowned self] in
            let id = try modelIdClosure()
            return self.items.first { $0.identifier == id }
        }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        make { [unowned self] in self.items }
    }

    func fetchOperation(by request: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        _ = request
        return make { [unowned self] in self.items }
    }

    func saveOperation(_ updateModelsBlock: @escaping () throws -> [T], _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Void> {
        make { [unowned self] in
            let updates = try updateModelsBlock()
            let deletes = try deleteIdsBlock()
            self.lock.lock()
            defer { self.lock.unlock() }
            self.saveCount += 1
            for item in updates {
                if self.storage[item.identifier] == nil { self.order.append(item.identifier) }
                self.storage[item.identifier] = item
            }
            for id in deletes {
                self.storage[id] = nil
                self.order.removeAll { $0 == id }
            }
        }
    }

    func saveBatchOperation(_ updateModelsBlock: @escaping () throws -> [T], _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Void> {
        saveOperation(updateModelsBlock, deleteIdsBlock)
    }

    func replaceOperation(_ newModelsBlock: @escaping () throws -> [T]) -> BaseOperation<Void> {
        make { [unowned self] in
            let items = try newModelsBlock()
            self.lock.lock()
            defer { self.lock.unlock() }
            self.storage = Dictionary(items.map { ($0.identifier, $0) }, uniquingKeysWith: { _, new in new })
            self.order = items.map(\.identifier)
        }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        make { [unowned self] in self.items.count }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        make { [unowned self] in
            self.lock.lock()
            defer { self.lock.unlock() }
            self.storage = [:]
            self.order = []
        }
    }
}

struct CovJError: Error, Equatable {
    let message: String
    init(_ message: String = "lane-j failure") { self.message = message }
}
