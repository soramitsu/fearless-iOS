import BigInt
import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class StakingRewardDestinationSetupTests: XCTestCase {
    func testSetup_whenNoData_thenProvidesEmptyModelsAndStartsInteractor() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertNil(fixture.view.rewardDestinationViewModel)
        XCTAssertNil(fixture.view.feeViewModel)
    }

    func testRewardDestinationInputs_whenReceived_thenBuildsViewModelAndRefreshesFee() {
        let fixture = makeFixture()

        provideReadyState(to: fixture)

        XCTAssertNotNil(fixture.view.rewardDestinationViewModel)
        XCTAssertEqual(fixture.view.rewardDestinationViewModel?.canApply, false)
        XCTAssertEqual(fixture.viewModelFactory.lastBondedAmount, 1)
        XCTAssertEqual(fixture.interactor.estimatedDestinations.count, 1)
    }

    func testSelectDestinations_thenUpdatesViewModelAndRefreshesFee() {
        let fixture = makeFixture()
        provideReadyState(to: fixture)
        fixture.interactor.resetEstimatedDestinations()

        fixture.presenter.selectRestakeDestination()
        XCTAssertEqual(fixture.view.rewardDestinationViewModel?.canApply, true)

        fixture.presenter.selectPayoutDestination()
        XCTAssertEqual(fixture.viewModelFactory.lastSelectedAddress, WestendStub.address)
        XCTAssertEqual(fixture.interactor.estimatedDestinations.count, 2)
    }

    func testPayoutAccountSelection_thenFetchesAccountsAndAppliesSelectedAccount() {
        let fixture = makeFixture()
        provideReadyState(to: fixture)

        fixture.presenter.selectPayoutAccount()
        XCTAssertTrue(fixture.interactor.didFetchPayoutAccounts)

        fixture.presenter.didReceiveAccounts(result: .success([fixture.stashAccount, fixture.payoutAccount]))
        fixture.wireframe.selectAccount(at: 1)

        XCTAssertEqual(fixture.wireframe.presentedAccounts.count, 2)
        XCTAssertEqual(fixture.viewModelFactory.lastSelectedAddress, fixture.payoutAddress)
        XCTAssertEqual(fixture.view.rewardDestinationViewModel?.canApply, true)
    }

    func testProceed_whenValid_thenRoutesToConfirmation() {
        let fixture = makeFixture()
        provideReadyState(to: fixture)

        fixture.presenter.selectRestakeDestination()
        fixture.presenter.proceed()

        XCTAssertEqual(fixture.wireframe.proceededChainId, fixture.chain.chainId)
        XCTAssertEqual(fixture.wireframe.proceededAssetId, fixture.asset.id)
        XCTAssertEqual(fixture.wireframe.proceededWalletId, fixture.selectedAccount.metaId)
        XCTAssertTrue(fixture.wireframe.didProceedWithRestake)
    }

    func testProceed_whenFeeMissing_thenRefreshesFeeAndDoesNotRoute() {
        let fixture = makeFixture()
        provideStateWithoutFee(to: fixture)
        fixture.interactor.resetEstimatedDestinations()

        fixture.presenter.proceed()

        XCTAssertNil(fixture.wireframe.proceededChainId)
        XCTAssertEqual(fixture.interactor.estimatedDestinations.count, 1)
    }

    func testDisplayLearnMore_thenShowsPayoutHelp() {
        let fixture = makeFixture()

        fixture.presenter.displayLearnMore()

        XCTAssertEqual(fixture.wireframe.webUrl, ApplicationConfig.shared.learnPayoutURL)
    }

    private func makeFixture() -> StakingRewardDestinationSetupFixture {
        let chainAsset = makeChainAsset()
        let selectedAccount = AccountGenerator.generateMetaAccount()
        let interactor = StakingRewardDestSetupInteractorInputSpy()
        let wireframe = StakingRewardDestSetupWireframeSpy()
        let viewModelFactory = ChangeRewardDestinationViewModelFactorySpy()
        let presenter = StakingRewardDestSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            rewardDestViewModelFactory: viewModelFactory,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            applicationConfig: ApplicationConfig.shared,
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            selectedAccount: selectedAccount,
            rewardChainAsset: nil,
            logger: LoggerSpy()
        )
        let view = StakingRewardDestSetupViewSpy()
        presenter.view = view

        let fixture = StakingRewardDestinationSetupFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            view: view,
            viewModelFactory: viewModelFactory,
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            selectedAccount: selectedAccount,
            stashAccount: makeAccount(address: WestendStub.address, name: "stash", chain: chainAsset.chain),
            controllerAccount: makeAccount(address: WestendStub.address, name: "controller", chain: chainAsset.chain),
            payoutAccount: makeAccount(
                address: "5Gh52T8TzDekJsosRp22SQ4uyGi8MfuwL8qMBJ1ASF1P8r8i",
                name: "new payout",
                chain: chainAsset.chain
            )
        )

        return fixture
    }

    private func provideReadyState(to fixture: StakingRewardDestinationSetupFixture) {
        provideStateWithoutFee(to: fixture)
        fixture.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000))))
    }

    private func provideStateWithoutFee(to fixture: StakingRewardDestinationSetupFixture) {
        fixture.presenter.didReceiveController(result: .success(fixture.controllerAccount))
        fixture.presenter.didReceiveStash(result: .success(fixture.stashAccount))
        fixture.presenter.didReceiveStashItem(
            result: .success(StashItem(stash: WestendStub.address, controller: WestendStub.address))
        )
        fixture.presenter.didReceiveAccountInfo(result: .success(WestendStub.accountInfo.item))
        fixture.presenter.didReceiveCalculator(result: .success(RewardCalculatorEngineSpy()))
        fixture.presenter.didReceiveStakingLedger(result: .success(WestendStub.ledgerInfo.item))
        fixture.presenter.didReceiveRewardDestinationAccount(
            result: .success(.payout(account: fixture.stashAccount))
        )
    }

    private func makeChainAsset() -> ChainAsset {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 0,
            addressPrefix: 42,
            assetPresicion: 12,
            staking: .relayChain
        )
        let asset = AssetModel(
            id: "unit",
            name: "Unit",
            symbol: "UNIT",
            precision: 12,
            isUtility: true,
            isNative: true,
            staking: .relayChain,
            type: .normal
        )
        chain.assets = [asset]

        return ChainAsset(chain: chain, asset: asset)
    }

    private func makeAccount(
        address: AccountAddress,
        name: String,
        chain: ChainModel
    ) -> fearless.ChainAccountResponse {
        let accountId = try! address.toAccountId()

        return fearless.ChainAccountResponse(
            chainId: chain.chainId,
            accountId: accountId,
            publicKey: accountId,
            name: name,
            cryptoType: .sr25519,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: chain.isEthereumBased,
            isChainAccount: false,
            walletId: "wallet-id"
        )
    }
}

private struct StakingRewardDestinationSetupFixture {
    let presenter: StakingRewardDestSetupPresenter
    let interactor: StakingRewardDestSetupInteractorInputSpy
    let wireframe: StakingRewardDestSetupWireframeSpy
    let view: StakingRewardDestSetupViewSpy
    let viewModelFactory: ChangeRewardDestinationViewModelFactorySpy
    let chain: ChainModel
    let asset: AssetModel
    let selectedAccount: MetaAccountModel
    let stashAccount: fearless.ChainAccountResponse
    let controllerAccount: fearless.ChainAccountResponse
    let payoutAccount: fearless.ChainAccountResponse

    var payoutAddress: AccountAddress {
        payoutAccount.toAddress() ?? ""
    }
}

private final class StakingRewardDestSetupInteractorInputSpy:
    StakingRewardDestSetupInteractorInputProtocol {
    private(set) var didSetup = false
    private(set) var didFetchPayoutAccounts = false
    private(set) var estimatedDestinations: [RewardDestination<AccountAddress>] = []

    func setup() {
        didSetup = true
    }

    func estimateFee(rewardDestination: RewardDestination<AccountAddress>) {
        estimatedDestinations.append(rewardDestination)
    }

    func fetchPayoutAccounts() {
        didFetchPayoutAccounts = true
    }

    func resetEstimatedDestinations() {
        estimatedDestinations = []
    }
}

private final class StakingRewardDestSetupViewSpy: StakingRewardDestSetupViewProtocol {
    let controller = UIViewController()
    let isSetup = true

    private(set) var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private(set) var rewardDestinationViewModel: ChangeRewardDestinationViewModel?

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
    }

    func didReceiveRewardDestination(viewModel: ChangeRewardDestinationViewModel?) {
        rewardDestinationViewModel = viewModel
    }

    func applyLocalization() {}
}

private final class ChangeRewardDestinationViewModelFactorySpy:
    ChangeRewardDestinationViewModelFactoryProtocol {
    private(set) var lastBondedAmount: Decimal?
    private(set) var lastSelectedAddress: AccountAddress?

    func createViewModel(
        from originalRewardDestination: RewardDestination<AccountAddress>,
        selectedRewardDestination: RewardDestination<fearless.ChainAccountResponse>?,
        bondedAmount: Decimal,
        calculator _: RewardCalculatorEngineProtocol,
        nomination _: Nomination?,
        priceData _: PriceData?
    ) -> ChangeRewardDestinationViewModel? {
        lastBondedAmount = bondedAmount
        lastSelectedAddress = selectedRewardDestination?.accountAddress.account

        return ChangeRewardDestinationViewModel(
            selectionViewModel: LocalizableResource { _ in
                RewardDestinationViewModel(
                    rewardViewModel: nil,
                    type: selectedRewardDestination?.viewModelType ?? originalRewardDestination.viewModelType
                )
            },
            canApply: selectedRewardDestination?.accountAddress != originalRewardDestination
        )
    }
}

private extension RewardDestination where A == AccountAddress {
    var account: AccountAddress? {
        switch self {
        case .restake:
            return nil
        case let .payout(account):
            return account
        }
    }

    var viewModelType: RewardDestinationTypeViewModel {
        switch self {
        case .restake:
            return .restake
        case let .payout(account):
            return .payout(icon: nil, title: "payout", address: account)
        }
    }
}

private extension RewardDestination where A == fearless.ChainAccountResponse {
    var viewModelType: RewardDestinationTypeViewModel {
        switch self {
        case .restake:
            return .restake
        case let .payout(account):
            return .payout(icon: nil, title: account.name, address: account.toAddress() ?? "")
        }
    }
}

private final class StakingRewardDestSetupWireframeSpy: StakingRewardDestSetupWireframeProtocol {
    private(set) var proceededChainId: ChainModel.Id?
    private(set) var proceededAssetId: AssetModel.Id?
    private(set) var proceededWalletId: String?
    private(set) var didProceedWithRestake = false
    private(set) var presentedAccounts: [fearless.ChainAccountResponse] = []
    private(set) var webUrl: URL?
    private var accountSelectionDelegate: ModalPickerViewControllerDelegate?
    private var accountSelectionContext: AnyObject?

    func proceed(
        view _: StakingRewardDestSetupViewProtocol?,
        rewardDestination: RewardDestination<fearless.ChainAccountResponse>,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    ) {
        proceededChainId = chain.chainId
        proceededAssetId = asset.id
        proceededWalletId = selectedAccount.metaId

        if case .restake = rewardDestination {
            didProceedWithRestake = true
        }
    }

    func presentAccountSelection(
        _ accounts: [fearless.ChainAccountResponse],
        selectedAccountItem _: fearless.ChainAccountResponse?,
        title _: LocalizableResource<String>,
        delegate: ModalPickerViewControllerDelegate,
        from _: ControllerBackedProtocol?,
        context: AnyObject?
    ) {
        presentedAccounts = accounts
        accountSelectionDelegate = delegate
        accountSelectionContext = context
    }

    func selectAccount(at index: Int) {
        accountSelectionDelegate?.modalPickerDidSelectModelAtIndex(index, context: accountSelectionContext)
    }

    func showWeb(url: URL, from _: ControllerBackedProtocol, style _: WebPresentableStyle) {
        webUrl = url
    }

    @discardableResult
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        true
    }

    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
}

private final class RewardCalculatorEngineSpy: RewardCalculatorEngineProtocol {
    let rewardAssetRate: Decimal = 1

    func calculateEarnings(
        amount: Decimal,
        validatorAccountId _: AccountId,
        isCompound _: Bool,
        period _: CalculationPeriod
    ) throws -> Decimal {
        amount * Decimal(2)
    }

    func calculateMaxEarnings(
        amount: Decimal,
        isCompound _: Bool,
        period _: CalculationPeriod
    ) -> Decimal {
        amount * Decimal(2)
    }

    func calculateAvgEarnings(
        amount: Decimal,
        isCompound _: Bool,
        period _: CalculationPeriod
    ) -> Decimal {
        amount
    }

    func calculatorReturn(
        isCompound _: Bool,
        period _: CalculationPeriod,
        type _: RewardReturnType
    ) -> Decimal {
        0.1
    }

    func maxEarningsTitle(locale _: Locale) -> String {
        "Max"
    }

    func avgEarningTitle(locale _: Locale) -> String {
        "Avg"
    }
}

private final class LoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}
