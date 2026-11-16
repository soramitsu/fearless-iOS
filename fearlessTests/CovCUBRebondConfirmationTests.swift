import XCTest
import SSFModels
import SoraFoundation
@testable import fearless

final class CovCUBRebondConfirmListenerSpy: StakingRebondConfirmationModelStateListener {
    private(set) var calls: [String] = []

    func provideFeeViewModel() { calls.append("fee") }
    func provideAssetViewModel() { calls.append("asset") }
    func provideConfirmationViewModel() { calls.append("confirmation") }
    func didSubmitRebonding(result _: Result<String, Error>) { calls.append("submit") }
    func feeParametersDidChanged() { calls.append("feeParams") }

    func reset() { calls.removeAll() }
}

final class CovCUBRebondConfirmationTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var view: CovCUBViewSpy!
    private var interactor: CovCUBInteractorSpy!
    private var wireframe: CovCUBWireframeSpy!
    private var logger: CovCUBLoggerSpy!
    private var validatingFactory: StakingDataValidatingFactory!
    private var window: UIWindow?

    override func setUpWithError() throws {
        try super.setUpWithError()
        chainAsset = CovCUBFixture.chainAsset()
        wallet = CovCUBFixture.wallet()
        view = CovCUBViewSpy()
        view.localizationManager = try XCTUnwrap(LocalizationManager(localization: "en"))
        interactor = CovCUBInteractorSpy()
        wireframe = CovCUBWireframeSpy()
        logger = CovCUBLoggerSpy()
        validatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        validatingFactory.view = view
    }

    override func tearDown() {
        CovCUBPresenterHost.tearDown(window)
        window = nil
        chainAsset = nil
        wallet = nil
        view = nil
        interactor = nil
        wireframe = nil
        logger = nil
        validatingFactory = nil
        super.tearDown()
    }

    private func makeState(_ variant: SelectedRebondVariant) -> StakingRebondConfirmationRelaychainViewModelState {
        StakingRebondConfirmationRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            logger: logger,
            variant: variant,
            dataValidatingFactory: validatingFactory,
            callFactory: CovCUBCallFactoryStub()
        )
    }

    private func makeFactory() -> StakingRebondConfirmationRelaychainViewModelFactory {
        StakingRebondConfirmationRelaychainViewModelFactory(
            balanceViewModelFactory: CovCUBFixture.balanceFactory(wallet: wallet),
            chainAsset: chainAsset,
            iconGenerator: CovCUBIconGenerator()
        )
    }

    private func makePresenter(
        state: StakingRebondConfirmationRelaychainViewModelState,
        authorizer: SubmissionAuthorizing = CovCUBAuthorizer(authorizes: true)
    ) -> StakingRebondConfirmationPresenter {
        let presenter = StakingRebondConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: makeFactory(),
            dataValidatingFactory: validatingFactory,
            chainAsset: chainAsset,
            viewModelState: state,
            wallet: wallet,
            logger: logger,
            submissionAuthorizer: authorizer
        )
        presenter.view = view
        return presenter
    }

    private func unbondingLedger() throws -> StakingLedger {
        try CovCUBFixture.ledger(active: 10, unlocking: [(1, 2), (2, 5), (3, 8)])
    }

    private func fillValid(_ state: StakingRebondConfirmationRelaychainViewModelState) throws {
        state.didReceiveStakingLedger(result: .success(try unbondingLedger()))
        state.didReceiveActiveEra(result: .success(CovCUBFixture.activeEra(4)))
        state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.1)))
        state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 2)))
        state.didReceiveController(result: .success(try CovCUBFixture.account(for: chainAsset, wallet: wallet)))
    }

    private func inputString(_ value: Decimal) -> String {
        AssetBalanceFormatterFactory()
            .createInputFormatter(for: chainAsset.asset.displayInfo)
            .value(for: CovCUBFixture.english)
            .string(from: value as NSNumber) ?? ""
    }

    // MARK: - State

    func testStateAmountsForEachVariant() throws {
        let all = makeState(.all)
        let last = makeState(.last)
        let custom = makeState(.custom(amount: 1.5))

        XCTAssertNil(all.inputAmount)
        XCTAssertNil(last.inputAmount)
        XCTAssertNil(all.builderClosure)
        XCTAssertNil(all.reuseIdentifier)
        XCTAssertNil(all.unbonding)
        XCTAssertEqual(custom.inputAmount, 1.5)
        XCTAssertEqual(custom.reuseIdentifier, "rebond")
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: custom.builderClosure), ["rebond"])

        for state in [all, last, custom] {
            state.didReceiveStakingLedger(result: .success(try unbondingLedger()))
            state.didReceiveActiveEra(result: .success(CovCUBFixture.activeEra(4)))
            XCTAssertEqual(state.unbonding, 5)
        }
        XCTAssertEqual(all.inputAmount, 5)
        XCTAssertEqual(last.inputAmount, 3)
        XCTAssertEqual(custom.inputAmount, 1.5)
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: all.builderClosure), ["rebond"])
    }

    func testStateOutputsNotifyListenerAndLogFailures() throws {
        let state = makeState(.custom(amount: 1))
        let listener = CovCUBRebondConfirmListenerSpy()
        state.setStateListener(listener)

        XCTAssertNil(state.selectableAccountAddress)
        state.didReceiveStashItem(result: .success(CovCUBFixture.stashItem(controller: "rebond-ctrl")))
        XCTAssertEqual(state.selectableAccountAddress, "rebond-ctrl")
        state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 3)))
        XCTAssertEqual(state.balance, 3)
        state.didReceiveAccountInfo(result: .success(nil))
        XCTAssertNil(state.balance)
        try fillValid(state)
        state.didReceiveController(result: .success(nil))
        XCTAssertNil(state.controller)
        state.didSubmitRebonding(result: .success("0x1"))
        XCTAssertEqual(state.fee, 0.1)

        XCTAssertEqual(listener.calls, [
            "confirmation", "asset", "feeParams",
            "asset", "confirmation",
            "fee",
            "confirmation", "feeParams",
            "confirmation", "feeParams",
            "submit"
        ])

        state.didReceiveAccountInfo(result: .failure(CovCUBTestError.failed))
        state.didReceiveStakingLedger(result: .failure(CovCUBTestError.failed))
        state.didReceiveFee(result: .failure(CovCUBTestError.failed))
        state.didReceiveController(result: .failure(CovCUBTestError.failed))
        state.didReceiveStashItem(result: .failure(CovCUBTestError.failed))
        state.didReceiveActiveEra(result: .failure(CovCUBTestError.failed))
        XCTAssertEqual(logger.errors.count, 6)
    }

    func testStateValidators() throws {
        let state = makeState(.custom(amount: 1))
        let listener = CovCUBRebondConfirmListenerSpy()
        state.setStateListener(listener)

        XCTAssertEqual(
            CovCUBFixture.validationResults(state.dataValidators(locale: CovCUBFixture.english)),
            [.error, .error, .error, .error]
        )
        XCTAssertEqual(wireframe.calls, ["rebondingTooHigh", "feeNotReceived", "feeTooHigh", "missingController"])
        XCTAssertEqual(listener.calls, ["feeParams"])

        try fillValid(state)
        XCTAssertEqual(
            CovCUBFixture.validationResults(state.dataValidators(locale: CovCUBFixture.english)),
            [nil, nil, nil, nil]
        )
    }

    // MARK: - Factory

    func testFactoryNeedsControllerAmountAndFee() throws {
        let factory = makeFactory()
        let state = makeState(.all)

        XCTAssertNil(factory.createViewModel(viewModelState: state))
        XCTAssertNil(factory.createFeeViewModel(viewModelState: state, priceData: nil))
        XCTAssertNil(factory.createAssetBalanceViewModel(viewModelState: state, priceData: nil))

        state.didReceiveController(result: .success(try CovCUBFixture.account(for: chainAsset, wallet: wallet)))
        XCTAssertNil(factory.createViewModel(viewModelState: state))

        try fillValid(state)
        let viewModel = try XCTUnwrap(factory.createViewModel(viewModelState: state))
        XCTAssertEqual(viewModel.senderAddress, try CovCUBFixture.address(for: chainAsset, wallet: wallet))
        XCTAssertEqual(viewModel.senderName, wallet.name)
        XCTAssertNotNil(viewModel.senderIcon)
        XCTAssertEqual(viewModel.amount.value(for: CovCUBFixture.english), inputString(5))

        XCTAssertNotNil(factory.createFeeViewModel(viewModelState: state, priceData: nil)?.value(for: CovCUBFixture.english))
        let asset = try XCTUnwrap(factory.createAssetBalanceViewModel(viewModelState: state, priceData: nil))
        XCTAssertNotNil(asset.value(for: CovCUBFixture.english).balance)
    }

    // MARK: - Presenter

    func testPresenterSetupAndStateDrivenUpdates() throws {
        let state = makeState(.custom(amount: 1))
        let presenter = makePresenter(state: state)

        presenter.setup()
        XCTAssertEqual(view.calls, ["noFee"])
        XCTAssertEqual(interactor.calls, ["setup", "estimate"])
        XCTAssertEqual(interactor.reuseIdentifiers, ["rebond"])
        XCTAssertTrue(state.stateListener === presenter)

        view.reset()
        try fillValid(state)
        XCTAssertEqual(view.calls, ["asset", "fee", "confirmation"])
        XCTAssertEqual(view.rebondConfirmation?.senderName, wallet.name)

        interactor.reset()
        presenter.feeParametersDidChanged()
        presenter.refreshFeeIfNeeded()
        XCTAssertEqual(interactor.calls, ["estimate", "estimate"])
    }

    func testPresenterConfirmValidatesAndSubmits() throws {
        let state = makeState(.custom(amount: 1))
        let authorizer = CovCUBAuthorizer(authorizes: true)
        let presenter = makePresenter(state: state, authorizer: authorizer)

        presenter.confirm()
        XCTAssertEqual(wireframe.calls, ["rebondingTooHigh"])
        XCTAssertEqual(authorizer.requests, 0)

        try fillValid(state)
        presenter.confirm()
        XCTAssertEqual(authorizer.requests, 1)
        XCTAssertEqual(view.calls.last, "startLoading")
        XCTAssertEqual(interactor.calls.last, "submit")
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: interactor.submittedClosures.last ?? nil), ["rebond"])
    }

    func testPresenterHandlesSubmissionAndAccountSelection() {
        let state = makeState(.custom(amount: 1))
        let presenter = makePresenter(state: state)
        window = CovCUBPresenterHost.show(view)

        presenter.didSubmitRebonding(result: .success("0x2"))
        presenter.didSubmitRebonding(result: .failure(CovCUBTestError.failed))
        XCTAssertEqual(view.calls, ["stopLoading", "stopLoading"])
        XCTAssertEqual(wireframe.calls, ["complete", "extrinsicFailed"])

        presenter.selectAccount()
        XCTAssertNil(view.controller.presentedViewController)

        state.didReceiveStashItem(result: .success(CovCUBFixture.stashItem(
            controller: "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq"
        )))
        presenter.selectAccount()
        CovCUBPresenterHost.waitForPresentation(on: view.controller)
        XCTAssertTrue(view.controller.presentedViewController is UIAlertController)

        presenter.view = nil
        presenter.didSubmitRebonding(result: .success("0x3"))
        XCTAssertEqual(wireframe.calls, ["complete", "extrinsicFailed"])
    }

    // MARK: - Interactors

    func testRebondAndRedeemInteractorsForwardToStrategy() {
        let rebondStrategy = CovCUBStrategySpy()
        let rebond = StakingRebondConfirmationInteractor(chainAsset: chainAsset, wallet: wallet, strategy: rebondStrategy)
        rebond.setup()
        rebond.estimateFee(builderClosure: nil, reuseIdentifier: "rebond-id")
        rebond.submit(builderClosure: nil)
        XCTAssertEqual(rebondStrategy.calls, ["setup", "estimate", "submit"])
        XCTAssertEqual(rebondStrategy.reuseIdentifiers, ["rebond-id"])

        let redeemStrategy = CovCUBStrategySpy()
        let redeem = StakingRedeemConfirmationInteractor(strategy: redeemStrategy)
        redeem.setup()
        redeem.estimateFee(builderClosure: nil, reuseIdentifier: nil)
        redeem.submit(builderClosure: nil)
        XCTAssertEqual(redeemStrategy.calls, ["setup", "estimate", "submit"])
        XCTAssertEqual(redeemStrategy.reuseIdentifiers, [nil])
    }
}
