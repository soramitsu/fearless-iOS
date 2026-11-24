import XCTest
import SSFModels
import SoraFoundation
@testable import fearless

final class CovCUBUnbondConfirmFactoryStub: StakingUnbondConfirmViewModelFactoryProtocol {
    func buildViewModel(viewModelState _: StakingUnbondConfirmViewModelState) -> StakingUnbondConfirmViewModel? { nil }

    func buildBondingDurationViewModel(
        viewModelState _: StakingUnbondConfirmViewModelState
    ) -> LocalizableResource<TitleWithSubtitleViewModel>? {
        LocalizableResource { _ in TitleWithSubtitleViewModel(title: "Period", subtitle: "1 day") }
    }
}

final class CovCUBUnbondPresentersTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var view: CovCUBViewSpy!
    private var interactor: CovCUBInteractorSpy!
    private var wireframe: CovCUBWireframeSpy!
    private var logger: CovCUBLoggerSpy!
    private var validatingFactory: StakingDataValidatingFactory!
    private var window: UIWindow?
    private let en = ["en"]

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

    // MARK: - Unbond setup

    private func makeSetup(
        state: StakingUnbondSetupViewModelState,
        factory: StakingUnbondSetupViewModelFactoryProtocol
    ) -> StakingUnbondSetupPresenter {
        let presenter = StakingUnbondSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: CovCUBFixture.balanceFactory(wallet: wallet),
            dataValidatingFactory: validatingFactory,
            viewModelFactory: factory,
            viewModelState: state,
            chainAsset: chainAsset,
            wallet: wallet,
            logger: logger
        )
        presenter.view = view
        return presenter
    }

    private func relaySetupState() -> StakingUnbondSetupRelaychainViewModelState {
        StakingUnbondSetupRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: CovCUBCallFactoryStub()
        )
    }

    private func fillValidSetup(_ state: StakingUnbondSetupRelaychainViewModelState) throws {
        state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 10)))
        state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.1)))
        state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 5)))
        state.didReceiveController(result: .success(try CovCUBFixture.account(for: chainAsset, wallet: wallet)))
        state.didReceiveExistentialDeposit(result: .success(CovCUBFixture.planks(1)))
    }

    func testUnbondSetupPresenterSetupProvidesInitialViewModels() throws {
        let state = relaySetupState()
        let presenter = makeSetup(state: state, factory: StakingUnbondSetupRelaychainViewModelFactory())

        presenter.setup()

        XCTAssertEqual(view.calls, ["input", "noFee", "duration", "asset", "title", "hints"])
        XCTAssertEqual(interactor.calls, ["setup"])
        XCTAssertEqual(
            view.title?.value(for: CovCUBFixture.english),
            R.string.localizable.stakingUnbond_v190(preferredLanguages: en)
        )
        XCTAssertEqual(view.input?.value(for: CovCUBFixture.english).displayAmount, "")
        XCTAssertTrue(state.stateListener === presenter)
    }

    func testUnbondSetupPresenterReactsToStateChanges() throws {
        let state = relaySetupState()
        let presenter = makeSetup(state: state, factory: StakingUnbondSetupRelaychainViewModelFactory())
        presenter.setup()
        view.reset()
        interactor.reset()

        state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 10)))
        state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.1)))
        XCTAssertEqual(view.calls, ["asset", "fee"])
        let footer = try XCTUnwrap(view.footerFee?.value(for: CovCUBFixture.english))
        XCTAssertEqual(footer.actionTitle.value(for: CovCUBFixture.english), R.string.localizable.commonContinue(preferredLanguages: en))
        XCTAssertFalse(footer.balanceViewModel.value(for: CovCUBFixture.english).amount.isEmpty)

        view.reset()
        presenter.selectAmountPercentage(0.5)
        XCTAssertEqual(view.calls, ["input", "asset"])
        XCTAssertEqual(view.input?.value(for: CovCUBFixture.english).decimalAmount, 5)
        presenter.updateAmount(2)
        XCTAssertEqual(state.inputAmount, 2)
        XCTAssertEqual(interactor.calls, ["estimate", "estimate"])
        XCTAssertEqual(interactor.reuseIdentifiers.last, state.reuseIdentifier)
        XCTAssertNotNil(interactor.estimatedClosures.last ?? nil)

        state.didReceiveFee(result: .failure(CovCUBTestError.failed))
        XCTAssertEqual(logger.errors.count, 1)
    }

    func testUnbondSetupPresenterProceedRunsValidation() throws {
        let state = relaySetupState()
        let presenter = makeSetup(state: state, factory: StakingUnbondSetupRelaychainViewModelFactory())
        presenter.setup()

        presenter.proceed()
        XCTAssertTrue(wireframe.calls.isEmpty)

        presenter.updateAmount(2)
        presenter.proceed()
        XCTAssertEqual(wireframe.calls, ["unbondingTooHigh"])

        try fillValidSetup(state)
        presenter.proceed()
        XCTAssertEqual(wireframe.calls, ["unbondingTooHigh", "proceed"])
        guard case let .relaychain(amount) = wireframe.unbondFlows.last else {
            return XCTFail("expected relaychain flow")
        }
        XCTAssertEqual(amount, 2)

        presenter.updateAmount(9.5)
        presenter.proceed()
        XCTAssertEqual(wireframe.calls.last, "stashKilled")
        let pendingAction = try XCTUnwrap(wireframe.pendingStashKilledAction)
        pendingAction()
        XCTAssertEqual(wireframe.calls, ["unbondingTooHigh", "proceed", "stashKilled", "proceed"])

        presenter.close()
        presenter.didTapBackButton()
        XCTAssertEqual(wireframe.calls.suffix(2), ["close", "dismiss"])
    }

    func testUnbondSetupPresenterForPoolProvidesAccount() throws {
        let state = StakingUnbondSetupPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: CovCUBCallFactoryStub()
        )
        let factory = StakingUnbondSetupPoolViewModelFactory(
            accountViewModelFactory: AccountViewModelFactory(iconGenerator: CovCUBIconGenerator())
        )
        let presenter = makeSetup(state: state, factory: factory)

        presenter.setup()

        XCTAssertEqual(view.calls, ["input", "noFee", "asset", "title", "account", "hints"])
        XCTAssertEqual(view.account?.name, wallet.name)

        state.didSetup()
        XCTAssertEqual(interactor.calls, ["setup", "estimate"])
        XCTAssertEqual(interactor.reuseIdentifiers.last, state.reuseIdentifier)
    }

    // MARK: - Unbond confirm

    private func makeConfirm(
        state: StakingUnbondConfirmViewModelState,
        factory: StakingUnbondConfirmViewModelFactoryProtocol? = nil,
        authorizer: SubmissionAuthorizing = CovCUBAuthorizer(authorizes: true)
    ) -> StakingUnbondConfirmPresenter {
        let presenter = StakingUnbondConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: factory ?? StakingUnbondConfirmRelaychainViewModelFactory(
                asset: chainAsset.asset,
                iconGenerator: CovCUBIconGenerator()
            ),
            balanceViewModelFactory: CovCUBFixture.balanceFactory(wallet: wallet),
            viewModelState: state,
            dataValidatingFactory: validatingFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            logger: logger,
            submissionAuthorizer: authorizer
        )
        presenter.view = view
        return presenter
    }

    private func relayConfirmState(amount: Decimal) -> StakingUnbondConfirmRelaychainViewModelState {
        StakingUnbondConfirmRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            inputAmount: amount,
            callFactory: CovCUBCallFactoryStub()
        )
    }

    private func fillValidConfirm(_ state: StakingUnbondConfirmRelaychainViewModelState) throws {
        state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 10)))
        state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.1)))
        state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 5)))
        state.didReceiveController(result: .success(try CovCUBFixture.account(for: chainAsset, wallet: wallet)))
    }

    func testUnbondConfirmPresenterSetupAndStateUpdates() throws {
        let state = relayConfirmState(amount: 2)
        let presenter = makeConfirm(state: state)

        presenter.setup()
        XCTAssertEqual(view.calls, ["asset", "noFee"])
        XCTAssertEqual(interactor.calls, ["setup", "estimate"])
        XCTAssertEqual(interactor.reuseIdentifiers, ["2false"])

        view.reset()
        try fillValidConfirm(state)
        XCTAssertEqual(view.calls, ["asset", "fee", "confirmation"])
        XCTAssertEqual(view.unbondConfirmation?.senderName, wallet.name)
        XCTAssertNotNil(view.fee?.value(for: CovCUBFixture.english))

        interactor.reset()
        presenter.didReceiveFeeError()
        XCTAssertEqual(interactor.calls, ["estimate"])
        XCTAssertNil(interactor.estimatedClosures.last ?? nil)

        state.didReceiveFee(result: .failure(CovCUBTestError.failed))
        XCTAssertEqual(logger.errors.count, 1)
    }

    func testUnbondConfirmPresenterShowsDurationFromFactory() {
        let presenter = makeConfirm(state: relayConfirmState(amount: 1), factory: CovCUBUnbondConfirmFactoryStub())

        presenter.setup()

        XCTAssertEqual(view.calls, ["asset", "noFee", "duration"])
        XCTAssertEqual(view.duration?.value(for: CovCUBFixture.english).subtitle, "1 day")
    }

    func testUnbondConfirmPresenterConfirmValidatesAndAuthorizes() throws {
        let state = relayConfirmState(amount: 2)
        let authorizer = CovCUBAuthorizer(authorizes: false)
        let presenter = makeConfirm(state: state, authorizer: authorizer)
        presenter.setup()

        presenter.confirm()
        XCTAssertEqual(wireframe.calls, ["unbondingTooHigh"])
        XCTAssertEqual(authorizer.requests, 0)

        try fillValidConfirm(state)
        view.reset()
        interactor.reset()
        presenter.confirm()
        XCTAssertEqual(authorizer.requests, 1)
        XCTAssertTrue(interactor.calls.isEmpty)

        authorizer.authorizes = true
        presenter.confirm()
        XCTAssertEqual(view.calls, ["startLoading"])
        XCTAssertEqual(interactor.calls, ["submit"])
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: interactor.submittedClosures.last ?? nil), ["unbond"])
    }

    func testUnbondConfirmPresenterHandlesSubmissionResults() {
        let presenter = makeConfirm(state: relayConfirmState(amount: 2))

        presenter.didSubmitUnbonding(result: .success("0xabc"))
        presenter.didSubmitUnbonding(result: .failure(CovCUBTestError.failed))
        XCTAssertEqual(view.calls, ["stopLoading", "stopLoading"])
        XCTAssertEqual(wireframe.calls, ["complete", "extrinsicFailed"])
        XCTAssertEqual(wireframe.hashes, ["0xabc"])

        presenter.view = nil
        presenter.didSubmitUnbonding(result: .success("0xdef"))
        XCTAssertEqual(wireframe.calls, ["complete", "extrinsicFailed"])

        presenter.didTapBackButton()
        XCTAssertEqual(wireframe.calls.last, "dismiss")
    }

    func testUnbondConfirmPresenterSelectAccountPresentsOptions() {
        let state = relayConfirmState(amount: 2)
        let presenter = makeConfirm(state: state)
        window = CovCUBPresenterHost.show(view)

        presenter.selectAccount()
        XCTAssertNil(view.controller.presentedViewController)

        let address = "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq"
        state.didReceiveStashItem(result: .success(CovCUBFixture.stashItem(controller: address)))
        presenter.selectAccount()
        CovCUBPresenterHost.waitForPresentation(on: view.controller)

        let alert = view.controller.presentedViewController as? UIAlertController
        XCTAssertNotNil(alert)
        XCTAssertEqual(alert?.title?.replacingOccurrences(of: "\n", with: ""), address)
    }

    func testUnbondConfirmPresenterForPoolState() throws {
        let state = StakingUnbondConfirmPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            inputAmount: 3,
            callFactory: CovCUBCallFactoryStub()
        )
        let factory = StakingUnbondConfirmPoolViewModelFactory(asset: chainAsset.asset, iconGenerator: CovCUBIconGenerator())
        let presenter = makeConfirm(state: state, factory: factory)

        presenter.setup()
        XCTAssertEqual(view.calls, ["confirmation", "asset", "noFee"])
        XCTAssertEqual(view.unbondConfirmation?.senderName, wallet.name)
        XCTAssertEqual(interactor.reuseIdentifiers, ["pool_unbond"])

        interactor.reset()
        state.didReceiveFee(result: .failure(CovCUBTestError.failed))
        XCTAssertEqual(interactor.calls, ["estimate"])
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: interactor.estimatedClosures.last ?? nil), ["pool_unbond_old"])
    }

    // MARK: - Interactors

    func testUnbondInteractorsForwardToStrategy() {
        let setupStrategy = CovCUBStrategySpy()
        let setupInteractor = StakingUnbondSetupInteractor(chainAsset: chainAsset, wallet: wallet, strategy: setupStrategy)
        setupInteractor.setup()
        setupInteractor.estimateFee(builderClosure: nil, reuseIdentifier: "setup-id")
        XCTAssertEqual(setupStrategy.calls, ["setup", "estimate"])
        XCTAssertEqual(setupStrategy.reuseIdentifiers, ["setup-id"])

        let confirmStrategy = CovCUBStrategySpy()
        let confirmInteractor = StakingUnbondConfirmInteractor(chainAsset: chainAsset, wallet: wallet, strategy: confirmStrategy)
        confirmInteractor.setup()
        confirmInteractor.estimateFee(builderClosure: nil, reuseIdentifier: "confirm-id")
        confirmInteractor.submit(builderClosure: nil)
        XCTAssertEqual(confirmStrategy.calls, ["setup", "estimate", "submit"])
        XCTAssertEqual(confirmStrategy.reuseIdentifiers, ["confirm-id"])
    }
}
