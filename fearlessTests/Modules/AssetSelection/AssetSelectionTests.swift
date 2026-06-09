import XCTest
import UIKit
import BigInt
import FearlessFoundation
import SSFModels
@testable import fearless

final class AssetSelectionTests: XCTestCase {
    func testSetup_whenCalled_thenStartsInteractor() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertEqual(fixture.interactor.setupCount, 1)
    }

    func testReceiveChains_whenFilteredAssetsExist_thenBuildsSelectableItems() {
        let fixture = makeFixture()
        let view = AssetSelectionViewSpy()
        let reloadExpectation = expectation(description: "reload")
        view.onReload = { reloadExpectation.fulfill() }
        fixture.presenter.view = view

        fixture.presenter.didReceiveChains(result: .success([fixture.chain]))

        wait(for: [reloadExpectation], timeout: 1)
        XCTAssertEqual(fixture.presenter.numberOfItems, 1)

        let item = fixture.presenter.item(at: 0) as? SelectableIconDetailsListViewModel
        XCTAssertEqual(item?.title, fixture.chain.name)
        XCTAssertEqual(item?.identifier, fixture.chain.chainId)
        XCTAssertEqual(item?.isSelected, true)
    }

    func testReceiveAccountInfo_whenBalanceArrives_thenRefreshesItemSubtitle() {
        let fixture = makeFixture()
        let view = AssetSelectionViewSpy()
        var reloadCount = 0
        let reloadExpectation = expectation(description: "reloads")
        reloadExpectation.expectedFulfillmentCount = 2
        view.onReload = {
            reloadCount += 1
            reloadExpectation.fulfill()
        }
        fixture.presenter.view = view

        fixture.presenter.didReceiveChains(result: .success([fixture.chain]))
        fixture.presenter.didReceiveAccountInfo(
            result: .success(makeAccountInfo(free: 1_000)),
            for: fixture.chainAssetKey
        )

        wait(for: [reloadExpectation], timeout: 1)
        XCTAssertEqual(reloadCount, 2)

        let item = fixture.presenter.item(at: 0) as? SelectableIconDetailsListViewModel
        XCTAssertEqual(item?.subtitle?.isEmpty, false)
    }

    func testSelectItem_whenItemSelected_thenCompletesWithChainAsset() {
        let fixture = makeFixture()
        let view = AssetSelectionViewSpy()
        let reloadExpectation = expectation(description: "reload")
        view.onReload = { reloadExpectation.fulfill() }
        fixture.presenter.view = view

        fixture.presenter.didReceiveChains(result: .success([fixture.chain]))
        wait(for: [reloadExpectation], timeout: 1)
        fixture.presenter.selectItem(at: 0)

        XCTAssertTrue(fixture.wireframe.completedView === view)
        XCTAssertEqual(fixture.wireframe.selectedChainAsset?.chain.chainId, fixture.chain.chainId)
        XCTAssertEqual(fixture.wireframe.selectedChainAsset?.asset.id, fixture.selectedAsset.id)
        XCTAssertNil(fixture.wireframe.completedContext)
    }

    func testReceiveChains_whenInteractorFails_thenPresentsError() {
        let fixture = makeFixture()
        let view = AssetSelectionViewSpy()
        fixture.presenter.view = view

        fixture.presenter.didReceiveChains(result: .failure(TestError.expected))

        XCTAssertTrue(fixture.wireframe.errorView === view)
        XCTAssertEqual(fixture.wireframe.presentedErrors.count, 1)
    }

    private func makeFixture() -> AssetSelectionFixture {
        let interactor = ChainSelectionInteractorInputSpy()
        let wireframe = AssetSelectionWireframeSpy()
        let wallet = AccountGenerator.generateMetaAccount().replacingName("Wallet")
        let selectedAsset = makeAsset(id: "selected", symbol: "dot")
        let filteredAsset = makeAsset(id: "filtered", symbol: "ksm")
        let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0)
        chain.assets = [selectedAsset, filteredAsset]
        let selectedChainAsset = ChainAsset(chain: chain, asset: selectedAsset)
        let accountId = wallet.fetch(for: chain.accountRequest())?.accountId

        let presenter = AssetSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            assetFilter: { $0.id == selectedAsset.id },
            type: .normal(chainAsset: selectedChainAsset),
            selectedMetaAccount: wallet,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            localizationManager: LocalizationManager.shared
        )

        return AssetSelectionFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            wallet: wallet,
            chain: chain,
            selectedAsset: selectedAsset,
            chainAssetKey: selectedChainAsset.uniqueKey(accountId: accountId!)
        )
    }

    private func makeAsset(id: String, symbol: String) -> AssetModel {
        AssetModel(
            id: id,
            name: symbol.uppercased(),
            symbol: symbol,
            precision: 2,
            icon: nil,
            currencyId: nil,
            existentialDeposit: nil,
            color: nil,
            isUtility: id == "selected",
            isNative: id == "selected",
            staking: nil,
            purchaseProviders: nil,
            type: nil,
            ethereumType: nil,
            priceProvider: nil,
            coingeckoPriceId: nil
        )
    }

    private func makeAccountInfo(free: BigUInt) -> AccountInfo {
        AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: free, reserved: 0, frozen: 0, flags: 0)
        )
    }
}

private struct AssetSelectionFixture {
    let presenter: AssetSelectionPresenter
    let interactor: ChainSelectionInteractorInputSpy
    let wireframe: AssetSelectionWireframeSpy
    let wallet: MetaAccountModel
    let chain: ChainModel
    let selectedAsset: AssetModel
    let chainAssetKey: ChainAssetKey
}

private final class AssetSelectionViewSpy: ChainSelectionViewProtocol {
    let controller = UIViewController()
    let isSetup = true

    var onReload: (() -> Void)?
    private(set) var reloadCount = 0
    private(set) var boundSearchViewModel: TextSearchViewModel?
    private(set) var reloadedIndexPaths: [IndexPath] = []

    func didReload() {
        reloadCount += 1
        onReload?()
    }

    func bind(viewModel: TextSearchViewModel?) {
        boundSearchViewModel = viewModel
    }

    func reloadCell(at indexPath: IndexPath) {
        reloadedIndexPaths.append(indexPath)
    }
}

private final class ChainSelectionInteractorInputSpy: ChainSelectionInteractorInputProtocol {
    private(set) var setupCount = 0

    func setup() {
        setupCount += 1
    }
}

private final class AssetSelectionWireframeSpy: AssetSelectionWireframeProtocol {
    private(set) weak var completedView: ChainSelectionViewProtocol?
    private(set) var selectedChainAsset: ChainAsset?
    private(set) var completedContext: Any?
    private(set) weak var errorView: ControllerBackedProtocol?
    private(set) var presentedErrors: [Error] = []
    private(set) var presentedMessages: [(message: String?, title: String)] = []

    func complete(
        on view: ChainSelectionViewProtocol,
        selecting chainAsset: ChainAsset,
        context: Any?
    ) {
        completedView = view
        selectedChainAsset = chainAsset
        completedContext = context
    }

    func present(error: Error, from view: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errorView = view
        presentedErrors.append(error)
        return true
    }

    func present(
        viewModel _: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {}

    func present(
        message: String?,
        title: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        presentedMessages.append((message, title))
    }

    func presentInfo(
        message: String?,
        title: String,
        from _: ControllerBackedProtocol?
    ) {
        presentedMessages.append((message, title))
    }
}

private enum TestError: Error {
    case expected
}

final class MockAccountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol {
    func subscribe(
        chainAsset: ChainAsset,
        accountId: AccountId,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {
        let accountInfo = AccountInfo(
            nonce: 0,
            consumers: 1,
            providers: 2,
            data: AccountData(
                free: BigUInt(100_000),
                reserved: 0,
                frozen: 0,
                flags: 0
            )
        )
        handler?.handleAccountInfo(
            result: .success(accountInfo),
            accountId: accountId,
            chainAsset: chainAsset
        )
    }

    func subscribe(
        chainsAssets: [ChainAsset],
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {
        chainsAssets.forEach { chainAsset in
            let accountInfo = AccountInfo(
                nonce: 0,
                consumers: 1,
                providers: 2,
                data: AccountData(
                    free: BigUInt(100_000),
                    reserved: 0,
                    frozen: 0,
                    flags: 0
                )
            )
            handler?.handleAccountInfo(
                result: .success(accountInfo),
                accountId: Data.random(of: 32)!,
                chainAsset: chainAsset
            )
        }
    }

    func reset() {}
    func unsubscribe(chainAsset _: ChainAsset) {}
    func update(wallet _: MetaAccountModel) {}
}
