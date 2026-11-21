import XCTest
import SSFModels
import SoraFoundation
import BigInt
import SSFUtils
@testable import fearless

enum CovCABCAPError: Error {
    case failed
}

final class CovCABCAPView: UIViewController, ControllerAccountViewProtocol {
    private(set) var reloaded: [ControllerAccountViewModel] = []
    private(set) var fees: [LocalizableResource<BalanceViewModelProtocol>] = []
    private(set) var chainNames: [String] = []
    private(set) var presentedControllers: [UIViewController] = []

    func reload(with viewModel: ControllerAccountViewModel) { reloaded.append(viewModel) }
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>) { fees.append(feeViewModel) }
    func didReceive(chainName: String) { chainNames.append(chainName) }
    func applyLocalization() {}

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
    }
}

final class CovCABCAPWireframe: ControllerAccountWireframeProtocol {
    private(set) var confirmations: [fearless.ChainAccountResponse] = []
    private(set) var closeCalls = 0
    private(set) var webURLs: [URL] = []
    private(set) var selections: [(accounts: [fearless.ChainAccountResponse], title: LocalizableResource<String>)] = []
    private(set) var sheetViewModels: [SheetAlertPresentableViewModel] = []

    func showConfirmation(
        from _: ControllerBackedProtocol?,
        controllerAccountItem: fearless.ChainAccountResponse,
        asset _: AssetModel,
        chain _: ChainModel,
        selectedAccount _: fearless.MetaAccountModel
    ) {
        confirmations.append(controllerAccountItem)
    }

    func close(view _: ControllerBackedProtocol?) {
        closeCalls += 1
    }

    func showWeb(url: URL, from _: ControllerBackedProtocol, style _: WebPresentableStyle) {
        webURLs.append(url)
    }

    func presentAccountSelection(
        _ accounts: [fearless.ChainAccountResponse],
        selectedAccountItem _: fearless.ChainAccountResponse?,
        title: LocalizableResource<String>,
        delegate _: ModalPickerViewControllerDelegate,
        from _: ControllerBackedProtocol?,
        context _: AnyObject?
    ) {
        selections.append((accounts, title))
    }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheetViewModels.append(viewModel)
    }

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        false
    }
}

final class CovCABCAPInteractor: ControllerAccountInteractorInputProtocol {
    private(set) var setupCalls = 0
    private(set) var feeAccounts: [fearless.ChainAccountResponse] = []
    private(set) var ledgerAddresses: [AccountAddress] = []
    private(set) var infoAddresses: [AccountAddress] = []

    func setup() { setupCalls += 1 }
    func estimateFee(for account: fearless.ChainAccountResponse) { feeAccounts.append(account) }
    func fetchLedger(controllerAddress: AccountAddress) { ledgerAddresses.append(controllerAddress) }
    func fetchControllerAccountInfo(controllerAddress: AccountAddress) { infoAddresses.append(controllerAddress) }
}

final class CovCABControllerAccountPresenterTests: XCTestCase {
    private var view: CovCABCAPView!
    private var wireframe: CovCABCAPWireframe!
    private var interactor: CovCABCAPInteractor!
    private var presenter: ControllerAccountPresenter!
    private var chain: ChainModel!
    private var current: fearless.ChainAccountResponse!
    private var other: fearless.ChainAccountResponse!
    private var third: fearless.ChainAccountResponse!

    override func setUp() {
        super.setUp()
        chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        makePresenter(chain: chain)
    }

    override func tearDown() {
        presenter = nil
        interactor = nil
        wireframe = nil
        view = nil
        chain = nil
        current = nil
        other = nil
        third = nil
        super.tearDown()
    }

    private func makePresenter(chain: ChainModel) {
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        let wallet = AccountGenerator.generateMetaAccount()
        current = wallet.fetch(for: chain.accountRequest())
        other = AccountGenerator.generateMetaAccount().fetch(for: chain.accountRequest())
        third = AccountGenerator.generateMetaAccount().fetch(for: chain.accountRequest())

        view = CovCABCAPView()
        view.localizationManager = LocalizationManager(localization: "en")
        wireframe = CovCABCAPWireframe()
        interactor = CovCABCAPInteractor()
        let validating = StakingDataValidatingFactory(presentable: wireframe)
        validating.view = view
        presenter = ControllerAccountPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: ControllerAccountViewModelFactory(currentAccountItem: current, iconGenerator: UniversalIconGenerator()),
            applicationConfig: ApplicationConfig.shared,
            chain: chain,
            asset: asset,
            selectedAccount: wallet,
            dataValidatingFactory: validating,
            logger: Logger.shared,
            balanceViewModelFactory: BalanceViewModelFactory(targetAssetInfo: asset.displayInfo, selectedMetaAccount: wallet)
        )
        presenter.view = view
    }

    private func address(_ account: fearless.ChainAccountResponse?) throws -> AccountAddress {
        try XCTUnwrap(account?.toAddress())
    }

    private func accountInfo(free: BigUInt) -> AccountInfo {
        AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: free, reserved: 0, frozen: 0, flags: 0))
    }

    func testDidLoadStartsInteractorAndSendsChainName() {
        presenter.didLoad(view: view)

        XCTAssertEqual(interactor.setupCalls, 1)
        XCTAssertEqual(view.chainNames, [chain.name])
    }

    func testStashItemResultsDriveReloadAndClose() throws {
        presenter.didReceiveStashItem(result: .failure(CovCABCAPError.failed))
        XCTAssertTrue(view.reloaded.isEmpty)

        let stash = StashItem(stash: try address(current), controller: try address(other))
        presenter.didReceiveStashItem(result: .success(stash))
        XCTAssertEqual(view.reloaded.count, 1)
        XCTAssertEqual(wireframe.closeCalls, 0)

        presenter.didReceiveStashAccount(result: .success(current))
        presenter.didReceiveControllerAccount(result: .success(other))
        XCTAssertEqual(view.reloaded.count, 3)
        XCTAssertEqual(view.reloaded.last?.controllerViewModel.value(for: Locale(identifier: "en")).name, other.name)

        presenter.didReceiveStashAccount(result: .failure(CovCABCAPError.failed))
        presenter.didReceiveControllerAccount(result: .failure(CovCABCAPError.failed))
        presenter.didReceiveAccounts(result: .failure(CovCABCAPError.failed))
        XCTAssertEqual(view.reloaded.count, 3)

        presenter.didReceiveStashItem(result: .success(nil))
        XCTAssertEqual(wireframe.closeCalls, 1)
        XCTAssertEqual(view.reloaded.count, 3)
    }

    func testFeeResultProvidesViewModel() {
        presenter.didReceiveFee(result: .failure(CovCABCAPError.failed))
        XCTAssertTrue(view.fees.isEmpty)

        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000))))
        XCTAssertEqual(view.fees.count, 1)
        XCTAssertFalse(view.fees.first?.value(for: Locale(identifier: "en")).amount.isEmpty ?? true)
    }

    func testRefreshFeePrefersStashThenChosenAccount() {
        presenter.refreshFeeIfNeeded()
        XCTAssertTrue(interactor.feeAccounts.isEmpty)

        presenter.didReceiveControllerAccount(result: .success(other))
        presenter.refreshFeeIfNeeded()
        XCTAssertEqual(interactor.feeAccounts, [other])

        presenter.didReceiveStashAccount(result: .success(current))
        presenter.refreshFeeIfNeeded()
        XCTAssertEqual(interactor.feeAccounts, [other, current])

        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(5))))
        presenter.refreshFeeIfNeeded()
        XCTAssertEqual(interactor.feeAccounts.count, 2)
    }

    func testStashAndControllerActionsShowAccountOptions() throws {
        presenter.handleStashAction()
        XCTAssertTrue(view.presentedControllers.isEmpty)

        let stash = StashItem(stash: try address(current), controller: try address(other))
        presenter.didReceiveStashItem(result: .success(stash))

        presenter.handleStashAction()
        presenter.handleControllerAction()

        XCTAssertEqual(view.presentedControllers.count, 2)
        XCTAssertTrue(view.presentedControllers.allSatisfy { $0 is UIAlertController })
        XCTAssertTrue(wireframe.selections.isEmpty)
    }

    func testLearnMoreOpensControllerArticle() {
        presenter.selectLearnMore()
        XCTAssertEqual(wireframe.webURLs, [ApplicationConfig.shared.learnControllerAccountURL])

        presenter.view = nil
        presenter.selectLearnMore()
        XCTAssertEqual(wireframe.webURLs.count, 1)
    }

    func testProceedRejectsAlreadyUsedController() throws {
        let stash = StashItem(stash: try address(current), controller: try address(other))
        presenter.didReceiveStashItem(result: .success(stash))
        presenter.didReceiveControllerAccount(result: .success(other))

        presenter.proceed()

        XCTAssertTrue(wireframe.confirmations.isEmpty)
        XCTAssertTrue(view.presentedControllers.last is SheetAletViewController)
    }

    func testProceedWithoutFeeRefreshesFee() throws {
        let stash = StashItem(stash: try address(current), controller: try address(other))
        presenter.didReceiveStashItem(result: .success(stash))
        presenter.didReceiveControllerAccount(result: .success(third))

        presenter.proceed()

        XCTAssertTrue(wireframe.confirmations.isEmpty)
        XCTAssertEqual(interactor.feeAccounts, [third])
    }

    func testProceedWarnsOnEmptyControllerBalanceThenConfirms() throws {
        let stash = StashItem(stash: try address(current), controller: try address(other))
        presenter.didReceiveStashItem(result: .success(stash))
        presenter.didReceiveControllerAccount(result: .success(third))
        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000))))
        presenter.didReceiveAccountInfo(result: .success(accountInfo(free: BigUInt(100_000_000_000))), address: try address(current))
        presenter.didReceiveStakingLedger(result: .success(nil))

        presenter.proceed()

        XCTAssertTrue(wireframe.confirmations.isEmpty)
        let warning = try XCTUnwrap(wireframe.sheetViewModels.last)
        XCTAssertEqual(
            warning.message,
            R.string.localizable.stakingControllerAccountZeroBalance(preferredLanguages: ["en"])
        )

        warning.actions.first?.handler?()
        XCTAssertEqual(wireframe.confirmations, [third])
    }

    func testProceedConfirmsWithFundedController() throws {
        let stash = StashItem(stash: try address(current), controller: try address(other))
        presenter.didReceiveStashItem(result: .success(stash))
        presenter.didReceiveControllerAccount(result: .success(third))
        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000))))
        presenter.didReceiveAccountInfo(result: .success(accountInfo(free: BigUInt(100_000_000_000))), address: try address(current))
        presenter.didReceiveAccountInfo(result: .success(accountInfo(free: BigUInt(50_000_000_000))), address: try address(third))
        presenter.didReceiveAccountInfo(result: .failure(CovCABCAPError.failed), address: try address(third))

        presenter.proceed()

        XCTAssertEqual(wireframe.confirmations, [third])
    }

    func testProceedBlockedByExistingLedger() throws {
        let stash = StashItem(stash: try address(current), controller: try address(other))
        presenter.didReceiveStashItem(result: .success(stash))
        presenter.didReceiveControllerAccount(result: .success(third))
        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000))))
        presenter.didReceiveAccountInfo(result: .success(accountInfo(free: BigUInt(100_000_000_000))), address: try address(current))
        presenter.didReceiveAccountInfo(result: .success(accountInfo(free: BigUInt(50_000_000_000))), address: try address(third))
        let ledgerPayload: [String: Any] = [
            "stash": Data(repeating: 3, count: 32).toHex(includePrefix: true),
            "total": "1",
            "active": "1",
            "unlocking": [],
            "claimedRewards": []
        ]
        let ledger = try JSONDecoder().decode(StakingLedger.self, from: JSONSerialization.data(withJSONObject: ledgerPayload))
        presenter.didReceiveStakingLedger(result: .success(ledger))
        presenter.didReceiveStakingLedger(result: .failure(CovCABCAPError.failed))

        presenter.proceed()

        XCTAssertTrue(wireframe.confirmations.isEmpty)
        XCTAssertTrue(view.presentedControllers.last is SheetAletViewController)
    }

    func testControllerBalanceClearedWhenAccountInfoMissing() throws {
        let stash = StashItem(stash: try address(current), controller: try address(other))
        presenter.didReceiveStashItem(result: .success(stash))
        presenter.didReceiveControllerAccount(result: .success(third))
        presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000))))
        presenter.didReceiveAccountInfo(result: .success(accountInfo(free: BigUInt(100_000_000_000))), address: try address(current))
        presenter.didReceiveAccountInfo(result: .success(accountInfo(free: BigUInt(50_000_000_000))), address: try address(third))
        presenter.didReceiveAccountInfo(result: .success(nil), address: try address(third))

        presenter.proceed()

        XCTAssertTrue(wireframe.confirmations.isEmpty)
        XCTAssertEqual(wireframe.sheetViewModels.count, 1)
    }

    func testPickerSelectionFetchesControllerInfo() throws {
        let stash = StashItem(stash: try address(current), controller: try address(other))
        presenter.didReceiveStashItem(result: .success(stash))
        let reloadsBefore = view.reloaded.count

        let otherAccount: fearless.ChainAccountResponse = try XCTUnwrap(other)
        let thirdAccount: fearless.ChainAccountResponse = try XCTUnwrap(third)
        presenter.modalPickerDidSelectModelAtIndex(1, context: PrimitiveContextWrapper(value: [otherAccount, thirdAccount]))

        XCTAssertEqual(interactor.ledgerAddresses, [try address(third)])
        XCTAssertEqual(interactor.infoAddresses, [try address(third)])
        XCTAssertEqual(view.reloaded.count, reloadsBefore + 1)

        presenter.modalPickerDidSelectModelAtIndex(0, context: PrimitiveContextWrapper(value: [otherAccount]))
        XCTAssertEqual(interactor.ledgerAddresses.count, 1)

        presenter.modalPickerDidSelectModelAtIndex(0, context: nil)
        XCTAssertEqual(view.reloaded.count, reloadsBefore + 2)
    }

    func testSoraControllerActionOpensAccountPicker() throws {
        makePresenter(chain: CovCABCAVSoraFixture.chain())
        let stash = StashItem(stash: try address(current), controller: try address(current))
        presenter.didReceiveStashItem(result: .success(stash))

        presenter.handleControllerAction()
        XCTAssertTrue(wireframe.selections.isEmpty)
        XCTAssertTrue(view.presentedControllers.isEmpty)

        presenter.didReceiveAccounts(result: .success([current, other]))
        presenter.handleControllerAction()

        XCTAssertEqual(wireframe.selections.count, 1)
        XCTAssertEqual(wireframe.selections.first?.accounts, [current, other])
        XCTAssertEqual(
            wireframe.selections.first?.title.value(for: Locale(identifier: "en")),
            R.string.localizable.stakingControllerAccountTitle(preferredLanguages: ["en"])
        )
    }
}

enum CovCABCAVSoraFixture {
    static func chain() -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: Data(repeating: 5, count: 32).toHex(),
            paraId: nil,
            name: "SORA Mainnet",
            xcm: nil,
            nodes: Set([ChainNodeModel(url: Constants.dummyURL, name: "node", apikey: nil)]),
            addressPrefix: 69,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}
