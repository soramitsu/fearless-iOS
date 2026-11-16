import XCTest
import BigInt
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SoraFoundation
@testable import fearless

final class CovCBPBMFRuntimeStub: SSFRuntimeCodingService.RuntimeProviderProtocol {
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

final class CovCBPBMFListener: StakingBondMoreModelStateListener {
    var events: [String] = []

    func didReceiveError(error _: Error) { events.append("error") }
    func didReceiveInsufficientlyFundsError() { events.append("insufficient") }
    func feeParametersDidChanged(viewModelState _: StakingBondMoreViewModelState) { events.append("feeParams") }
    func provideAmountInputViewModel() { events.append("input") }
    func provideFee() { events.append("fee") }
    func provideAsset() { events.append("asset") }
}

final class CovCBPBMFViewDouble: StakingBondMoreViewProtocol {
    let backing = UIViewController()
    var inputs: [LocalizableResource<IAmountInputViewModel>] = []
    var assets: [LocalizableResource<AssetBalanceViewModelProtocol>] = []
    var fees: [LocalizableResource<NetworkFeeFooterViewModelProtocol>?] = []
    var hints: [LocalizableResource<String>?] = []

    var isSetup: Bool { true }
    var controller: UIViewController { backing }

    func applyLocalization() {}
    func didReceiveInput(viewModel: LocalizableResource<IAmountInputViewModel>) { inputs.append(viewModel) }
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) { assets.append(viewModel) }
    func didReceiveFee(viewModel: LocalizableResource<NetworkFeeFooterViewModelProtocol>?) { fees.append(viewModel) }
    func didReceiveHints(viewModel: LocalizableResource<String>?) { hints.append(viewModel) }
}

final class CovCBPBMFWireframeDouble: StakingBondMoreWireframeProtocol {
    var confirmations: [StakingBondMoreConfirmationFlow] = []
    var dismissCount = 0
    var amountTooHighCount = 0

    func showConfirmation(
        from _: ControllerBackedProtocol?,
        flow: StakingBondMoreConfirmationFlow,
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel
    ) {
        confirmations.append(flow)
    }

    func dismiss(view _: ControllerBackedProtocol?) { dismissCount += 1 }
    func presentAmountTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) { amountTooHighCount += 1 }
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { true }
}

final class CovCBPBMFInteractorDouble: StakingBondMoreInteractorInputProtocol {
    var setupCount = 0
    var feeRequests: [String?] = []

    func setup() { setupCount += 1 }
    func estimateFee(reuseIdentifier: String?, builderClosure _: ExtrinsicBuilderClosure?) { feeRequests.append(reuseIdentifier) }
}

final class CovCBPBMFStrategyDouble: StakingBondMoreStrategy {
    var calls: [String] = []

    func setup() { calls.append("setup") }
    func estimateFee(builderClosure _: ExtrinsicBuilderClosure?, reuseIdentifier: String?) { calls.append("fee-\(reuseIdentifier ?? "nil")") }
}

final class CovCBPBondMoreFlowTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
    private let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
    private let wallet = AccountGenerator.generateMetaAccount()

    private var chainAsset: ChainAsset { ChainAsset(chain: chain, asset: asset) }

    private func makeValidating() -> StakingDataValidatingFactory {
        StakingDataValidatingFactory(presentable: CovCBPBMFWireframeDouble())
    }

    private func makeCallFactory() -> SubstrateCallFactoryDefault {
        SubstrateCallFactoryDefault(runtimeService: CovCBPBMFRuntimeStub())
    }

    private func makeRelayState() -> StakingBondMoreRelaychainViewModelState {
        StakingBondMoreRelaychainViewModelState(chainAsset: chainAsset, dataValidatingFactory: makeValidating(), callFactory: makeCallFactory())
    }

    private func makePoolState() -> StakingBondMorePoolViewModelState {
        StakingBondMorePoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
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

    private func isRelaychain(_ flow: StakingBondMoreConfirmationFlow?, amount: Decimal) -> Bool {
        if case let .relaychain(value) = flow { return value == amount }
        return false
    }

    private func isPool(_ flow: StakingBondMoreConfirmationFlow?, amount: Decimal) -> Bool {
        if case let .pool(value) = flow { return value == amount }
        return false
    }

    // MARK: - Relaychain state

    func testRelaychainStateReceivesData() throws {
        let state = makeRelayState()
        let listener = CovCBPBMFListener()
        state.setStateListener(listener)

        XCTAssertEqual(state.feeReuseIdentifier, "bond_extra")
        XCTAssertNotNil(state.builderClosure)
        XCTAssertNil(state.bondMoreConfirmationFlow)

        state.didReceiveAccountInfo(result: .success(accountInfo(free: 100_000_000_000)))
        XCTAssertEqual(state.balance, 10)
        state.didReceiveAccountInfo(result: .success(nil))
        XCTAssertNil(state.balance)
        state.didReceiveAccountInfo(result: .failure(CommonError.undefined))

        state.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 10_000_000_000)))
        XCTAssertEqual(state.fee, 1)
        state.didReceiveFee(result: .failure(CommonError.undefined))

        state.didReceiveExistentialDeposit(result: .success(10_000_000_000))
        state.didReceiveExistentialDeposit(result: .failure(CommonError.undefined))
        state.didReceiveStash(result: .failure(CommonError.undefined))
        state.didReceiveStashItem(result: .failure(CommonError.undefined))
        state.extrinsicServiceUpdated()

        XCTAssertEqual(listener.events, ["asset", "asset", "error", "fee", "error", "error", "error", "error", "feeParams"])

        state.updateAmount(3)
        XCTAssertEqual(state.amount, 3)
        XCTAssertTrue(isRelaychain(state.bondMoreConfirmationFlow, amount: 3))
        XCTAssertEqual(Array(listener.events.suffix(2)), ["asset", "feeParams"])
    }

    func testRelaychainStatePercentageAndValidators() throws {
        let state = makeRelayState()
        let listener = CovCBPBMFListener()
        state.setStateListener(listener)

        state.selectAmountPercentage(0.5)
        XCTAssertTrue(listener.events.isEmpty)

        XCTAssertEqual(state.validators(using: locale).count, 4)
        XCTAssertFalse(passes(state.validators(using: locale)))
        XCTAssertEqual(listener.events, ["feeParams"])

        state.didReceiveAccountInfo(result: .success(accountInfo(free: 100_000_000_000)))
        state.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 10_000_000_000)))
        state.didReceiveExistentialDeposit(result: .success(10_000_000_000))
        listener.events.removeAll()

        state.selectAmountPercentage(0.5)
        XCTAssertEqual(state.amount, 4)
        XCTAssertEqual(listener.events, ["input", "asset"])

        let account = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
        state.didReceiveStash(result: .success(account))
        state.didReceiveStashItem(result: .success(StashItem(stash: "stash", controller: "controller")))
        XCTAssertTrue(passes(state.validators(using: locale)))

        state.didReceiveExistentialDeposit(result: .success(90_000_000_000))
        listener.events.removeAll()
        state.selectAmountPercentage(1)
        XCTAssertEqual(listener.events, ["insufficient"])
        XCTAssertFalse(passes(state.validators(using: locale)))
    }

    // MARK: - Pool state

    func testPoolStateReceivesDataAndValidates() throws {
        let state = makePoolState()
        let listener = CovCBPBMFListener()
        state.setStateListener(listener)

        XCTAssertEqual(state.feeReuseIdentifier, "bond_extra")
        XCTAssertNotNil(state.builderClosure)
        XCTAssertNil(state.bondMoreConfirmationFlow)
        XCTAssertEqual(state.accountAddress, try XCTUnwrap(wallet.fetch(for: chain.accountRequest())).toAddress())
        XCTAssertEqual(state.validators(using: locale).count, 3)

        XCTAssertFalse(passes(state.validators(using: locale)))
        XCTAssertEqual(listener.events, ["feeParams"])

        state.didReceiveAccountInfo(result: .success(accountInfo(free: 100_000_000_000)))
        state.didReceiveAccountInfo(result: .failure(CommonError.undefined))
        state.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 10_000_000_000)))
        state.didReceiveFee(result: .failure(CommonError.undefined))
        state.didReceiveExistentialDeposit(result: .success(10_000_000_000))
        state.didReceiveExistentialDeposit(result: .failure(CommonError.undefined))
        state.extrinsicServiceUpdated()
        XCTAssertEqual(Array(listener.events.dropFirst()), ["asset", "error", "fee", "error", "error", "feeParams"])

        listener.events.removeAll()
        state.selectAmountPercentage(0.25)
        XCTAssertEqual(state.amount, 2)
        XCTAssertEqual(listener.events, ["input", "asset"])
        XCTAssertTrue(isPool(state.bondMoreConfirmationFlow, amount: 2))
        XCTAssertTrue(passes(state.validators(using: locale)))

        state.updateAmount(20)
        XCTAssertFalse(passes(state.validators(using: locale)))

        state.didReceiveAccountInfo(result: .success(nil))
        XCTAssertNil(state.balance)
        listener.events.removeAll()
        state.selectAmountPercentage(1)
        XCTAssertTrue(listener.events.isEmpty)

        state.didReceiveAccountInfo(result: .success(accountInfo(free: 10_000_000_000)))
        listener.events.removeAll()
        state.selectAmountPercentage(1)
        XCTAssertEqual(listener.events, ["insufficient"])
    }

    // MARK: - Hint factories and interactor

    func testHintFactoriesAndInteractor() {
        let expected = R.string.localizable.stakingHintRewardBondMore(preferredLanguages: ["en"])
        let relayHint = StakingBondMoreRelaychainViewModelFactory().buildHintViewModel(viewModelState: makeRelayState(), locale: locale)
        let poolHint = StakingBondMorePoolViewModelFactory().buildHintViewModel(viewModelState: makePoolState(), locale: locale)
        XCTAssertEqual(relayHint?.value(for: locale), expected)
        XCTAssertEqual(poolHint?.value(for: locale), expected)

        let strategy = CovCBPBMFStrategyDouble()
        let interactor = StakingBondMoreInteractor(chainAsset: chainAsset, wallet: wallet, strategy: strategy)
        interactor.setup()
        interactor.estimateFee(reuseIdentifier: "id", builderClosure: nil)
        XCTAssertEqual(strategy.calls, ["setup", "fee-id"])
    }

    // MARK: - Presenter

    private func makePresenter(
        state: StakingBondMoreViewModelState? = nil
    ) -> (StakingBondMorePresenter, CovCBPBMFViewDouble, CovCBPBMFWireframeDouble, CovCBPBMFInteractorDouble) {
        let view = CovCBPBMFViewDouble()
        let wireframe = CovCBPBMFWireframeDouble()
        let interactor = CovCBPBMFInteractorDouble()
        let presenter = StakingBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: BalanceViewModelFactory(targetAssetInfo: asset.displayInfo, selectedMetaAccount: wallet),
            viewModelFactory: StakingBondMoreRelaychainViewModelFactory(),
            viewModelState: state ?? makePoolState(),
            dataValidatingFactory: makeValidating(),
            networkFeeViewModelFactory: NetworkFeeViewModelFactory(),
            chainAsset: chainAsset,
            wallet: wallet,
            logger: nil
        )
        presenter.view = view
        return (presenter, view, wireframe, interactor)
    }

    func testPresenterSetupProvidesInitialViewModels() {
        let (presenter, view, _, interactor) = makePresenter()

        presenter.setup()

        XCTAssertEqual(view.inputs.count, 1)
        XCTAssertEqual(view.hints.count, 1)
        XCTAssertNotNil(view.hints.first ?? nil)
        XCTAssertEqual(view.fees.count, 1)
        XCTAssertNil(view.fees.first ?? nil)
        XCTAssertEqual(interactor.setupCount, 1)
        XCTAssertEqual(interactor.feeRequests, ["bond_extra"])
    }

    func testPresenterContinueShowsConfirmationAfterValidation() {
        let state = makePoolState()
        let (presenter, view, wireframe, interactor) = makePresenter(state: state)
        presenter.setup()

        presenter.handleContinueAction()
        XCTAssertTrue(wireframe.confirmations.isEmpty)

        state.didReceiveAccountInfo(result: .success(accountInfo(free: 100_000_000_000)))
        state.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 10_000_000_000)))
        state.didReceiveExistentialDeposit(result: .success(10_000_000_000))
        presenter.updateAmount(2)
        XCTAssertEqual(interactor.feeRequests.count, 2)

        presenter.handleContinueAction()
        XCTAssertEqual(wireframe.confirmations.count, 1)
        XCTAssertTrue(isPool(wireframe.confirmations.first, amount: 2))

        presenter.selectAmountPercentage(0)
        XCTAssertEqual(wireframe.amountTooHighCount, 1)

        presenter.didTapBackButton()
        XCTAssertEqual(wireframe.dismissCount, 1)
        withExtendedLifetime(view) {}
    }

    func testPresenterFeeAssetAndErrors() throws {
        let state = makeRelayState()
        let (presenter, view, wireframe, interactor) = makePresenter(state: state)
        presenter.setup()

        state.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 10_000_000_000)))
        let fee = try XCTUnwrap(view.fees.last ?? nil).value(for: locale)
        XCTAssertFalse(fee.balanceViewModel.value(for: locale).amount.isEmpty)

        state.didReceiveAccountInfo(result: .success(accountInfo(free: 30_000_000_000)))
        let deadline = Date().addingTimeInterval(2)
        while view.assets.isEmpty, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertEqual(view.assets.count, 1)

        presenter.didReceiveError(error: CommonError.undefined)
        presenter.feeParametersDidChanged(viewModelState: state)
        XCTAssertEqual(interactor.feeRequests.last, "bond_extra")

        presenter.view = nil
        presenter.didReceiveInsufficientlyFundsError()
        XCTAssertEqual(wireframe.amountTooHighCount, 0)
    }
}
