import BigInt
import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class StakingRewardDestConfirmTests: XCTestCase {
    func testSetup_whenNoData_thenStartsInteractorAndProvidesEmptyFee() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertNil(fixture.view.feeViewModel)
        XCTAssertNil(fixture.view.confirmationViewModel)
    }

    func testModelInputs_whenReceived_thenProvidesConfirmationAndEstimatesFee() {
        let fixture = makeFixture()

        provideStateWithoutFee(to: fixture)

        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.first?.rewardDestination, fixture.rewardDestination.accountAddress)
        XCTAssertEqual(fixture.view.confirmationViewModel?.senderName, "controller")
        XCTAssertEqual(fixture.viewModelFactory.lastStashItem?.stash, WestendStub.address)
    }

    func testConfirm_whenValid_thenStartsLoadingAndSubmits() {
        let fixture = makeFixture()
        provideReadyState(to: fixture)

        fixture.presenter.confirm()

        XCTAssertTrue(fixture.view.didStartLoadingCalled)
        XCTAssertEqual(fixture.interactor.submitCalls.count, 1)
        XCTAssertEqual(fixture.interactor.submitCalls.first?.rewardDestination, fixture.rewardDestination.accountAddress)
    }

    func testConfirm_whenFeeMissing_thenRefreshesFeeAndDoesNotSubmit() {
        let fixture = makeFixture()
        provideStateWithoutFee(to: fixture)
        fixture.interactor.resetEstimateFeeCalls()

        fixture.presenter.confirm()

        XCTAssertFalse(fixture.view.didStartLoadingCalled)
        XCTAssertTrue(fixture.interactor.submitCalls.isEmpty)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
    }

    func testSubmitResult_whenSuccessAndFailure_thenStopsLoadingAndRoutes() {
        let successFixture = makeFixture()
        successFixture.presenter.didSubmitRewardDest(result: .success("0xhash"))

        XCTAssertTrue(successFixture.view.didStopLoadingCalled)
        XCTAssertTrue(successFixture.wireframe.completedView === successFixture.view)

        let failureFixture = makeFixture()
        failureFixture.presenter.didSubmitRewardDest(result: .failure(TestError.expected))

        XCTAssertTrue(failureFixture.view.didStopLoadingCalled)
        XCTAssertTrue(failureFixture.wireframe.didPresentExtrinsicFailed)
    }

    func testAccountOptions_whenAddressesAvailable_thenRoutesSenderAndPayout() {
        let fixture = makeFixture()
        provideReadyState(to: fixture)

        fixture.presenter.presentSenderAccountOptions()
        XCTAssertEqual(fixture.wireframe.accountOptionsAddress, WestendStub.address)
        XCTAssertEqual(fixture.wireframe.accountOptionsChainId, fixture.chain.chainId)

        fixture.presenter.presentPayoutAccountOptions()
        XCTAssertEqual(fixture.wireframe.accountOptionsAddress, fixture.payoutAddress)
        XCTAssertEqual(fixture.wireframe.accountOptionsChainId, fixture.chain.chainId)
    }

    private func makeFixture() -> StakingRewardDestConfirmFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let controllerAccount = makeAccount(address: WestendStub.address, name: "controller", chain: chainAsset.chain)
        let payoutAccount = makeAccount(
            address: "5Gh52T8TzDekJsosRp22SQ4uyGi8MfuwL8qMBJ1ASF1P8r8i",
            name: "new payout",
            chain: chainAsset.chain
        )
        let interactor = StakingRewardDestConfirmInteractorInputSpy()
        let wireframe = StakingRewardDestConfirmWireframeSpy()
        let viewModelFactory = StakingRewardDestConfirmVMFactorySpy()
        let rewardDestination = RewardDestination<fearless.ChainAccountResponse>.payout(account: payoutAccount)
        let presenter = StakingRewardDestConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            rewardDestination: rewardDestination,
            confirmModelFactory: viewModelFactory,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            wallet: wallet,
            logger: LoggerSpy()
        )
        let view = StakingRewardDestConfirmViewSpy()
        presenter.view = view

        return StakingRewardDestConfirmFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            view: view,
            viewModelFactory: viewModelFactory,
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            wallet: wallet,
            rewardDestination: rewardDestination,
            controllerAccount: controllerAccount,
            payoutAccount: payoutAccount
        )
    }

    private func provideReadyState(to fixture: StakingRewardDestConfirmFixture) {
        provideStateWithoutFee(to: fixture)
        fixture.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000))))
    }

    private func provideStateWithoutFee(to fixture: StakingRewardDestConfirmFixture) {
        fixture.presenter.didReceiveController(result: .success(fixture.controllerAccount))
        fixture.presenter.didReceiveStashItem(
            result: .success(StashItem(stash: WestendStub.address, controller: WestendStub.address))
        )
        fixture.presenter.didReceiveAccountInfo(result: .success(WestendStub.accountInfo.item))
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

private struct StakingRewardDestConfirmFixture {
    let presenter: StakingRewardDestConfirmPresenter
    let interactor: StakingRewardDestConfirmInteractorInputSpy
    let wireframe: StakingRewardDestConfirmWireframeSpy
    let view: StakingRewardDestConfirmViewSpy
    let viewModelFactory: StakingRewardDestConfirmVMFactorySpy
    let chain: ChainModel
    let asset: AssetModel
    let wallet: MetaAccountModel
    let rewardDestination: RewardDestination<fearless.ChainAccountResponse>
    let controllerAccount: fearless.ChainAccountResponse
    let payoutAccount: fearless.ChainAccountResponse

    var payoutAddress: AccountAddress {
        payoutAccount.toAddress() ?? ""
    }
}

private final class StakingRewardDestConfirmInteractorInputSpy:
    StakingRewardDestConfirmInteractorInputProtocol {
    private(set) var didSetup = false
    private(set) var estimateFeeCalls: [(rewardDestination: RewardDestination<AccountAddress>, stashItem: StashItem)] = []
    private(set) var submitCalls: [(rewardDestination: RewardDestination<AccountAddress>, stashItem: StashItem)] = []

    func setup() {
        didSetup = true
    }

    func estimateFee(for rewardDestination: RewardDestination<AccountAddress>, stashItem: StashItem) {
        estimateFeeCalls.append((rewardDestination, stashItem))
    }

    func submit(rewardDestination: RewardDestination<AccountAddress>, for stashItem: StashItem) {
        submitCalls.append((rewardDestination, stashItem))
    }

    func resetEstimateFeeCalls() {
        estimateFeeCalls = []
    }
}

private final class StakingRewardDestConfirmViewSpy: StakingRewardDestConfirmViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = false
    var localizationManager: LocalizationManagerProtocol? = LocalizationManagerProtocolSpy()

    private(set) var confirmationViewModel: StakingRewardDestConfirmViewModel?
    private(set) var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private(set) var didStartLoadingCalled = false
    private(set) var didStopLoadingCalled = false

    func didReceiveConfirmation(viewModel: StakingRewardDestConfirmViewModel) {
        confirmationViewModel = viewModel
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
    }

    func didStartLoading() {
        didStartLoadingCalled = true
    }

    func didStopLoading() {
        didStopLoadingCalled = true
    }

    func applyLocalization() {}
}

private final class StakingRewardDestConfirmVMFactorySpy:
    StakingRewardDestConfirmVMFactoryProtocol {
    private(set) var lastStashItem: StashItem?
    private(set) var lastRewardDestination: RewardDestination<fearless.ChainAccountResponse>?

    func createViewModel(
        from stashItem: StashItem,
        rewardDestination: RewardDestination<fearless.ChainAccountResponse>,
        controller: fearless.ChainAccountResponse?
    ) throws -> StakingRewardDestConfirmViewModel {
        lastStashItem = stashItem
        lastRewardDestination = rewardDestination

        return StakingRewardDestConfirmViewModel(
            senderIcon: EmptyAccountIcon(),
            senderName: controller?.name ?? stashItem.controller,
            rewardDestination: rewardDestination.viewModelType
        )
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

private final class StakingRewardDestConfirmWireframeSpy: StakingRewardDestConfirmWireframeProtocol {
    private(set) weak var completedView: StakingRewardDestConfirmViewProtocol?
    private(set) var didPresentExtrinsicFailed = false
    private(set) var accountOptionsAddress: AccountAddress?
    private(set) var accountOptionsChainId: ChainModel.Id?

    func complete(from view: StakingRewardDestConfirmViewProtocol?) {
        completedView = view
    }

    func presentAccountOptions(
        from _: ControllerBackedProtocol,
        address: String,
        chain: ChainModel,
        locale _: Locale,
        exportClosure _: (() -> Void)?
    ) {
        accountOptionsAddress = address
        accountOptionsChainId = chain.chainId
    }

    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) {
        didPresentExtrinsicFailed = true
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

private final class LocalizationManagerProtocolSpy: LocalizationManagerProtocol {
    var selectedLocalization = "en"
    let availableLocalizations = ["en"]

    func addObserver(
        with _: AnyObject,
        queue _: DispatchQueue?,
        closure _: @escaping LocalizationChangeClosure
    ) {}

    func removeObserver(by _: AnyObject) {}
}

private final class LoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}

private enum TestError: Error {
    case expected
}
