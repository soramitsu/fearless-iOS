import XCTest
import BigInt
import RobinHood
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
import SoraFoundation
@testable import fearless

final class CovCBPBMCRuntimeStub: SSFRuntimeCodingService.RuntimeProviderProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
    var snapshot: RuntimeSnapshot?

    func setup() {}
    func setupHot() {}
    func cleanup() {}
    func readySnapshot() async throws -> RuntimeSnapshot { throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable }
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> { BaseOperation() }
    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable
    }
}

final class CovCBPBMCListener: StakingBondMoreConfirmationModelStateListener {
    var events: [String] = []

    func provideFeeViewModel() { events.append("fee") }
    func provideAssetViewModel() { events.append("asset") }
    func provideConfirmationViewModel() { events.append("confirmation") }
    func refreshFeeIfNeeded() { events.append("refresh") }
    func didReceiveError(error _: Error) { events.append("error") }
    func didSubmitBonding(result: Result<String, Error>) { events.append((try? result.get()).map { "submit-\($0)" } ?? "submit-failure") }
}

final class CovCBPBMCRecordingController: UIViewController {
    var presentedControllers: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
    }
}

final class CovCBPBMCViewDouble: StakingBondMoreConfirmationViewProtocol, FWTransferSealShowing {
    let recorder = CovCBPBMCRecordingController()
    var confirmations: [StakingBondMoreConfirmViewModel] = []
    var assets: [LocalizableResource<AssetBalanceViewModelProtocol>] = []
    var fees: [LocalizableResource<BalanceViewModelProtocol>?] = []
    var events: [String] = []

    var isSetup: Bool { true }
    var controller: UIViewController { recorder }
    var loadableContentView: UIView { recorder.view }
    var shouldDisableInteractionWhenLoading: Bool { false }

    func applyLocalization() {}
    func didStartLoading() { events.append("start") }
    func didStopLoading() { events.append("stop") }
    func didReceiveConfirmation(viewModel: StakingBondMoreConfirmViewModel) { confirmations.append(viewModel) }
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) { assets.append(viewModel) }
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) { fees.append(viewModel) }
    func didReachTransferStage(_ stage: FWSealStage) { events.append("stage-\(stage)") }
    func didBreakTransfer() { events.append("break") }
}

final class CovCBPBMCWireframeDouble: StakingBondMoreConfirmationWireframeProtocol {
    var completedHashes: [String] = []
    var dismissCount = 0
    var extrinsicFailedCount = 0

    func complete(from _: StakingBondMoreConfirmationViewProtocol, chainAsset _: ChainAsset, extrinsicHash: String) {
        completedHashes.append(extrinsicHash)
    }

    func dismiss(view _: ControllerBackedProtocol?) { dismissCount += 1 }
    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) { extrinsicFailedCount += 1 }
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { true }
}

final class CovCBPBMCInteractorDouble: StakingBondMoreConfirmationInteractorInputProtocol {
    var setupCount = 0
    var feeIdentifiers: [String?] = []
    var submitCount = 0

    func setup() { setupCount += 1 }
    func estimateFee(builderClosure _: ExtrinsicBuilderClosure?, reuseIdentifier: String?) { feeIdentifiers.append(reuseIdentifier) }
    func submit(builderClosure _: ExtrinsicBuilderClosure?) { submitCount += 1 }
}

final class CovCBPBMCAuthorizerStub: SubmissionAuthorizing {
    var allow = true

    func authorizeSubmission(from _: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
        completion(allow)
    }
}

final class CovCBPBMCThrowingFactory: StakingBondMoreConfirmViewModelFactoryProtocol {
    var shouldThrow = true

    func createViewModel(
        account _: fearless.MetaAccountModel,
        amount _: Decimal,
        state _: StakingBondMoreConfirmationViewModelState,
        locale _: Locale,
        priceData _: PriceData?
    ) throws -> StakingBondMoreConfirmViewModel? {
        if shouldThrow { throw CommonError.undefined }
        return nil
    }
}

final class CovCBPBMCStrategyDouble: StakingBondMoreConfirmationStrategy {
    var calls: [String] = []

    func setup() { calls.append("setup") }
    func estimateFee(builderClosure _: ExtrinsicBuilderClosure?, reuseIdentifier: String?) { calls.append("fee-\(reuseIdentifier ?? "nil")") }
    func submit(builderClosure: ExtrinsicBuilderClosure?) { calls.append(builderClosure == nil ? "submit-nil" : "submit") }
}

final class CovCBPBondMoreConfirmFlowTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
    private let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
    private let wallet = AccountGenerator.generateMetaAccount()

    private var chainAsset: ChainAsset { ChainAsset(chain: chain, asset: asset) }
    private var balanceFactory: BalanceViewModelFactory {
        BalanceViewModelFactory(targetAssetInfo: asset.displayInfo, selectedMetaAccount: wallet)
    }

    private func makeValidating() -> StakingDataValidatingFactory {
        StakingDataValidatingFactory(presentable: CovCBPBMCWireframeDouble())
    }

    private func makeCallFactory() -> SubstrateCallFactoryDefault {
        SubstrateCallFactoryDefault(runtimeService: CovCBPBMCRuntimeStub())
    }

    private func makeRelayState(amount: Decimal = 2) -> StakingBondMoreConfirmationRelaychainViewModelState {
        StakingBondMoreConfirmationRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            amount: amount,
            dataValidatingFactory: makeValidating(),
            callFactory: makeCallFactory()
        )
    }

    private func makePoolState(amount: Decimal = 2) -> StakingBondMoreConfirmationPoolViewModelState {
        StakingBondMoreConfirmationPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            amount: amount,
            dataValidatingFactory: makeValidating(),
            callFactory: makeCallFactory()
        )
    }

    private func accountInfo(free: BigUInt) -> AccountInfo {
        AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: free, reserved: 0, frozen: 0))
    }

    private func passes(_ validators: [DataValidating]) -> Bool {
        var passed = false
        DataValidationRunner(validators: validators).runValidation { passed = true }
        return passed
    }

    private func walletAddress() throws -> String {
        try XCTUnwrap(wallet.fetch(for: chain.accountRequest())).toAddress() ?? ""
    }

    // MARK: - States

    func testRelaychainStateEventsAndValidators() throws {
        let state = makeRelayState()
        let listener = CovCBPBMCListener()
        state.setStateListener(listener)

        XCTAssertEqual(state.feeReuseIdentifier, "bond_extra")
        XCTAssertNotNil(state.builderClosure)
        XCTAssertNil(state.accountAddress)
        XCTAssertEqual(state.validators(using: locale).count, 3)
        XCTAssertFalse(passes(state.validators(using: locale)))
        XCTAssertEqual(listener.events, ["refresh"])
        listener.events.removeAll()

        state.didReceiveAccountInfo(result: .success(accountInfo(free: 100_000_000_000)))
        state.didReceiveAccountInfo(result: .failure(CommonError.undefined))
        state.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 10_000_000_000)))
        state.didReceiveFee(result: .failure(CommonError.undefined))
        state.didReceiveStash(result: .success(wallet.fetch(for: chain.accountRequest())))
        state.didReceiveStash(result: .failure(CommonError.undefined))
        state.didReceiveStashItem(result: .success(StashItem(stash: "stash", controller: "controller")))
        state.didReceiveStashItem(result: .failure(CommonError.undefined))
        state.didSubmitBonding(result: .success("0x1"))
        state.didSubmitBonding(result: .failure(CommonError.undefined))

        XCTAssertEqual(listener.events, [
            "asset", "confirmation", "error", "fee", "error", "confirmation", "refresh", "error", "error",
            "submit-0x1", "submit-failure"
        ])
        XCTAssertEqual(state.accountAddress, "controller")
        XCTAssertEqual(state.balance, 10)
        XCTAssertEqual(state.fee, 1)
        XCTAssertTrue(passes(state.validators(using: locale)))

        state.didReceiveAccountInfo(result: .success(nil))
        XCTAssertNil(state.balance)
        XCTAssertFalse(passes(state.validators(using: locale)))
    }

    func testPoolStateEventsAndValidators() throws {
        let state = makePoolState()
        let listener = CovCBPBMCListener()
        state.setStateListener(listener)

        XCTAssertEqual(state.feeReuseIdentifier, "bond_extra")
        XCTAssertNotNil(state.builderClosure)
        XCTAssertEqual(state.accountAddress, try walletAddress())
        XCTAssertEqual(state.validators(using: locale).count, 2)
        XCTAssertFalse(passes(state.validators(using: locale)))

        state.didReceiveAccountInfo(result: .success(accountInfo(free: 100_000_000_000)))
        state.didReceiveAccountInfo(result: .failure(CommonError.undefined))
        state.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 10_000_000_000)))
        state.didReceiveFee(result: .failure(CommonError.undefined))
        state.didSubmitBonding(result: .success("0x2"))

        XCTAssertEqual(listener.events, ["refresh", "asset", "confirmation", "error", "fee", "error", "submit-0x2"])
        XCTAssertTrue(passes(state.validators(using: locale)))

        state.didReceiveAccountInfo(result: .success(nil))
        XCTAssertFalse(passes(state.validators(using: locale)))
    }

    // MARK: - View model factories

    func testRelaychainConfirmFactoryBuildsViewModel() throws {
        let factory = StakingBondMoreConfirmRelaychainViewModelFactory(
            chainAsset: chainAsset,
            iconGenerator: UniversalIconGenerator(),
            balanceViewModelFactory: balanceFactory
        )
        let viewModel = try XCTUnwrap(
            try factory.createViewModel(account: wallet, amount: 3, state: makeRelayState(), locale: locale, priceData: nil)
        )
        let expectedAmount = balanceFactory.balanceFromPrice(3, priceData: nil, usageCase: .listCrypto).value(for: locale).amount

        XCTAssertEqual(viewModel.accountViewModel?.title, wallet.name)
        XCTAssertEqual(viewModel.accountViewModel?.subtitle, try walletAddress())
        XCTAssertEqual(viewModel.amountViewModel?.title, expectedAmount)
        XCTAssertNotNil(viewModel.senderIcon)

        let stake = try XCTUnwrap(viewModel.amount).value(for: locale)
        let amountString = try XCTUnwrap(
            AssetBalanceFormatterFactory().createTokenFormatter(for: chainAsset.assetDisplayInfo, usageCase: .detailsCrypto)
                .value(for: locale).stringFromDecimal(3)
        )
        XCTAssertEqual(
            stake.amountTitle.string,
            R.string.localizable.poolStakingStakeMoreAmountTitle(amountString, preferredLanguages: ["en"])
        )
        XCTAssertNotNil(factory.createStakedAmountViewModel(1))
    }

    func testPoolConfirmFactoryRequiresPoolState() throws {
        let factory = StakingBondMoreConfirmPoolViewModelFactory(
            chainAsset: chainAsset,
            iconGenerator: UniversalIconGenerator(),
            balanceViewModelFactory: balanceFactory
        )

        XCTAssertNil(factory.createViewModel(account: wallet, amount: 3, state: makeRelayState(), locale: locale, priceData: nil))

        let price = PriceData(currencyId: "usd", priceId: "dot", price: "5", fiatDayChange: nil, coingeckoPriceId: nil)
        let viewModel = try XCTUnwrap(factory.createViewModel(account: wallet, amount: 3, state: makePoolState(), locale: locale, priceData: price))
        XCTAssertEqual(viewModel.accountViewModel?.title, wallet.name)
        XCTAssertNotNil(viewModel.amountViewModel?.subtitle)
        XCTAssertTrue(try XCTUnwrap(viewModel.amount).value(for: locale).amountTitle.string.contains("3"))
    }

    // MARK: - Presenter

    private struct CovCEnv {
        let presenter: StakingBondMoreConfirmationPresenter
        let view: CovCBPBMCViewDouble
        let wireframe: CovCBPBMCWireframeDouble
        let interactor: CovCBPBMCInteractorDouble
        let authorizer: CovCBPBMCAuthorizerStub
    }

    private func makeEnv(
        state: StakingBondMoreConfirmationViewModelState,
        factory: StakingBondMoreConfirmViewModelFactoryProtocol? = nil
    ) -> CovCEnv {
        let wireframe = CovCBPBMCWireframeDouble()
        let interactor = CovCBPBMCInteractorDouble()
        let authorizer = CovCBPBMCAuthorizerStub()
        let presenter = StakingBondMoreConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: factory ?? StakingBondMoreConfirmPoolViewModelFactory(
                chainAsset: chainAsset,
                iconGenerator: UniversalIconGenerator(),
                balanceViewModelFactory: balanceFactory
            ),
            balanceViewModelFactory: balanceFactory,
            viewModelState: state,
            dataValidatingFactory: makeValidating(),
            chainAsset: chainAsset,
            wallet: wallet,
            logger: nil,
            submissionAuthorizer: authorizer
        )
        let view = CovCBPBMCViewDouble()
        presenter.view = view
        return CovCEnv(presenter: presenter, view: view, wireframe: wireframe, interactor: interactor, authorizer: authorizer)
    }

    func testPresenterSetupProvidesViewModels() {
        let state = makePoolState()
        let env = makeEnv(state: state)

        env.presenter.setup()

        XCTAssertEqual(env.view.assets.count, 1)
        XCTAssertEqual(env.view.fees.count, 1)
        XCTAssertNil(env.view.fees.first ?? nil)
        XCTAssertEqual(env.interactor.setupCount, 1)
        XCTAssertEqual(env.interactor.feeIdentifiers, ["bond_extra"])

        let deadline = Date().addingTimeInterval(2)
        while env.view.confirmations.isEmpty, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertEqual(env.view.confirmations.first?.accountViewModel?.title, wallet.name)

        state.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 10_000_000_000)))
        XCTAssertNotNil(env.view.fees.last ?? nil)
        env.presenter.refreshFeeIfNeeded()
        XCTAssertEqual(env.interactor.feeIdentifiers.count, 1)
    }

    func testPresenterConfirmSubmitsAfterValidation() {
        let state = makePoolState()
        let env = makeEnv(state: state)
        env.presenter.setup()

        env.presenter.confirm()
        XCTAssertEqual(env.interactor.submitCount, 0)

        state.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 10_000_000_000)))
        state.didReceiveAccountInfo(result: .success(accountInfo(free: 100_000_000_000)))

        env.authorizer.allow = false
        env.presenter.confirm()
        XCTAssertEqual(env.interactor.submitCount, 0)

        env.authorizer.allow = true
        env.presenter.confirm()
        XCTAssertEqual(env.interactor.submitCount, 1)
        XCTAssertEqual(env.view.events, ["start", "stage-\(FWSealStage.ready)"])
    }

    func testPresenterSubmitResultsAndNavigation() {
        let env = makeEnv(state: makePoolState())

        env.presenter.didSubmitBonding(result: .success("0xabc"))
        XCTAssertEqual(env.wireframe.completedHashes, ["0xabc"])
        XCTAssertEqual(env.view.events, ["stop", "stage-\(FWSealStage.accepted)"])

        env.presenter.didSubmitBonding(result: .failure(CommonError.network))
        XCTAssertEqual(env.wireframe.extrinsicFailedCount, 1)
        XCTAssertEqual(env.view.events.last, "break")

        env.presenter.selectAccount()
        XCTAssertTrue(env.view.recorder.presentedControllers.first is UIAlertController)

        env.presenter.didTapBackButton()
        XCTAssertEqual(env.wireframe.dismissCount, 1)

        env.presenter.didReceiveError(error: CommonError.undefined)
        env.presenter.view = nil
        env.presenter.didSubmitBonding(result: .success("0xdef"))
        env.presenter.selectAccount()
        XCTAssertEqual(env.wireframe.completedHashes, ["0xabc"])
        XCTAssertEqual(env.view.recorder.presentedControllers.count, 1)
    }

    func testPresenterHandlesFactoryFailuresAndMissingAddress() {
        let factory = CovCBPBMCThrowingFactory()
        let env = makeEnv(state: makeRelayState(), factory: factory)

        env.presenter.provideConfirmationViewModel()
        factory.shouldThrow = false
        env.presenter.provideConfirmationViewModel()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertTrue(env.view.confirmations.isEmpty)

        env.presenter.selectAccount()
        XCTAssertTrue(env.view.recorder.presentedControllers.isEmpty)
    }

    func testInteractorForwardsToStrategy() {
        let strategy = CovCBPBMCStrategyDouble()
        let interactor = StakingBondMoreConfirmationInteractor(chainAsset: chainAsset, wallet: wallet, strategy: strategy)

        interactor.setup()
        interactor.estimateFee(builderClosure: nil, reuseIdentifier: "bond")
        interactor.submit(builderClosure: nil)

        XCTAssertEqual(strategy.calls, ["setup", "fee-bond", "submit-nil"])
    }
}
