import XCTest
import SSFModels
import SoraFoundation
@testable import fearless

final class CovCUBRedeemRebondSetupPresentersTests: XCTestCase {
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

    // MARK: - Redeem confirmation

    private func makeRedeemPresenter(
        state: StakingRedeemConfirmationViewModelState,
        factory: StakingRedeemConfirmationViewModelFactoryProtocol,
        authorizer: SubmissionAuthorizing = CovCUBAuthorizer(authorizes: true)
    ) -> StakingRedeemConfirmationPresenter {
        let presenter = StakingRedeemConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: factory,
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

    private func relayRedeem() -> (StakingRedeemConfirmationRelaychainViewModelState, StakingRedeemConfirmationRelaychainViewModelFactory) {
        let state = StakingRedeemConfirmationRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: CovCUBCallFactoryStub()
        )
        let factory = StakingRedeemConfirmationRelaychainViewModelFactory(
            asset: chainAsset.asset,
            balanceViewModelFactory: CovCUBFixture.balanceFactory(wallet: wallet),
            iconGenerator: CovCUBIconGenerator()
        )
        return (state, factory)
    }

    private func fillValidRedeem(_ state: StakingRedeemConfirmationRelaychainViewModelState) throws {
        state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 1, unlocking: [(2, 3)])))
        state.didReceiveActiveEra(result: .success(CovCUBFixture.activeEra(4)))
        state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.1)))
        state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 1)))
        state.didReceiveController(result: .success(try CovCUBFixture.account(for: chainAsset, wallet: wallet)))
        state.didReceiveSlashingSpans(result: .success(try CovCUBFixture.slashingSpans(priorCount: 1)))
    }

    func testRedeemPresenterSetupAndStateDrivenUpdates() throws {
        let (state, factory) = relayRedeem()
        let presenter = makeRedeemPresenter(state: state, factory: factory)

        presenter.setup()
        XCTAssertEqual(view.calls, ["noFee", "hints"])
        XCTAssertEqual(interactor.calls, ["setup", "estimate"])
        XCTAssertEqual(interactor.reuseIdentifiers, ["0"])
        XCTAssertTrue(view.hints?.value(for: CovCUBFixture.english).isEmpty ?? false)

        view.reset()
        try fillValidRedeem(state)
        XCTAssertEqual(view.calls, ["asset", "confirmation", "fee", "confirmation"])
        XCTAssertEqual(view.redeemConfirmation?.senderName, wallet.name)
        XCTAssertEqual(
            view.redeemConfirmation?.title.value(for: CovCUBFixture.english),
            R.string.localizable.commonConfirmTitle(preferredLanguages: en)
        )
        XCTAssertEqual(interactor.reuseIdentifiers.last, "2")

        state.didReceiveFee(result: .failure(CovCUBTestError.failed))
        XCTAssertEqual(logger.errors.count, 1)
    }

    func testRedeemPresenterConfirmValidatesAuthorizesAndSubmits() throws {
        let (state, factory) = relayRedeem()
        let authorizer = CovCUBAuthorizer(authorizes: false)
        let presenter = makeRedeemPresenter(state: state, factory: factory, authorizer: authorizer)

        presenter.confirm()
        XCTAssertEqual(wireframe.calls, ["noRedeemables"])

        try fillValidRedeem(state)
        presenter.confirm()
        XCTAssertEqual(authorizer.requests, 1)
        XCTAssertFalse(interactor.calls.contains("submit"))

        authorizer.authorizes = true
        presenter.confirm()
        XCTAssertEqual(view.calls.last, "startLoading")
        XCTAssertEqual(interactor.calls.last, "submit")
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: interactor.submittedClosures.last ?? nil), ["withdraw_unbonded"])
    }

    func testRedeemPresenterSubmissionResultsAndNavigation() {
        let (state, factory) = relayRedeem()
        let presenter = makeRedeemPresenter(state: state, factory: factory)
        window = CovCUBPresenterHost.show(view)

        presenter.didSubmitRedeeming(result: .success("0xr"))
        presenter.didSubmitRedeeming(result: .failure(CovCUBTestError.failed))
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

        presenter.didTapBackButton()
        XCTAssertEqual(wireframe.calls.last, "dismiss")

        presenter.view = nil
        presenter.didSubmitRedeeming(result: .success("0xs"))
        XCTAssertEqual(wireframe.calls, ["complete", "extrinsicFailed", "dismiss"])
    }

    func testRedeemPresenterForPoolState() throws {
        let state = StakingRedeemConfirmationPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: CovCUBCallFactoryStub()
        )
        let factory = StakingRedeemConfirmationPoolViewModelFactory(
            asset: chainAsset.asset,
            balanceViewModelFactory: CovCUBFixture.balanceFactory(wallet: wallet),
            iconGenerator: CovCUBIconGenerator()
        )
        let presenter = makeRedeemPresenter(state: state, factory: factory)

        presenter.setup()
        XCTAssertEqual(view.calls, ["noFee", "hints"])

        view.reset()
        state.didReceiveStakeInfo(result: .success(try CovCUBFixture.poolMember(points: 1, unbonding: [(1, 2)])))
        state.didReceiveActiveEra(result: .success(CovCUBFixture.activeEra(2)))
        XCTAssertEqual(view.calls, ["asset", "confirmation"])
        XCTAssertEqual(
            view.redeemConfirmation?.title.value(for: CovCUBFixture.english),
            R.string.localizable.stakingRedeem(preferredLanguages: en)
        )
    }

    // MARK: - Rebond setup

    private func makeRebondSetup() -> StakingRebondSetupPresenter {
        let presenter = StakingRebondSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            balanceViewModelFactory: CovCUBFixture.balanceFactory(wallet: wallet),
            dataValidatingFactory: validatingFactory,
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            selectedAccount: wallet,
            logger: logger
        )
        presenter.view = view
        return presenter
    }

    func testRebondSetupPresenterSetupAndInputs() throws {
        let presenter = makeRebondSetup()

        presenter.setup()
        XCTAssertEqual(view.calls, ["input", "noFee"])
        XCTAssertEqual(interactor.calls, ["setup"])

        view.reset()
        presenter.selectAmountPercentage(0.5)
        presenter.updateAmount(1)
        XCTAssertTrue(view.calls.isEmpty)
        XCTAssertNil(presenter.unbonding)

        presenter.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 3, unlocking: [(4, 9), (1, 2)])))
        XCTAssertTrue(view.calls.isEmpty)
        presenter.didReceiveActiveEra(result: .success(CovCUBFixture.activeEra(5)))
        XCTAssertEqual(presenter.unbonding, 4)
        XCTAssertEqual(view.calls, ["asset"])

        view.reset()
        presenter.selectAmountPercentage(0.5)
        XCTAssertEqual(view.calls, ["input", "asset"])
        XCTAssertEqual(view.input?.value(for: CovCUBFixture.english).decimalAmount, 2)

        presenter.updateAmount(3)
        XCTAssertEqual(view.calls, ["input", "asset", "asset"])

        presenter.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.2)))
        XCTAssertEqual(view.calls.last, "fee")
        XCTAssertNotNil(view.fee?.value(for: CovCUBFixture.english))
    }

    func testRebondSetupPresenterLogsFailures() {
        let presenter = makeRebondSetup()

        presenter.didReceiveFee(result: .failure(CovCUBTestError.failed))
        presenter.didReceiveStakingLedger(result: .failure(CovCUBTestError.failed))
        presenter.didReceiveActiveEra(result: .failure(CovCUBTestError.failed))
        presenter.didReceiveController(result: .failure(CovCUBTestError.failed))
        presenter.didReceiveStashItem(result: .failure(CovCUBTestError.failed))
        presenter.didReceiveAccountInfo(result: .failure(CovCUBTestError.failed))

        XCTAssertEqual(logger.errors.count, 6)
        XCTAssertTrue(view.calls.isEmpty)
    }

    func testRebondSetupPresenterProceedValidatesBeforeNavigating() throws {
        let presenter = makeRebondSetup()

        presenter.proceed()
        XCTAssertEqual(wireframe.calls, ["rebondingTooHigh"])

        presenter.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 3, unlocking: [(4, 9)])))
        presenter.didReceiveActiveEra(result: .success(CovCUBFixture.activeEra(5)))
        presenter.updateAmount(2)
        presenter.proceed()
        XCTAssertEqual(wireframe.calls, ["rebondingTooHigh", "feeNotReceived"])
        XCTAssertEqual(interactor.calls, ["estimate"])

        presenter.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.1)))
        presenter.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 0.05)))
        presenter.proceed()
        XCTAssertEqual(wireframe.calls.last, "feeTooHigh")

        presenter.didReceiveAccountInfo(result: .success(nil))
        presenter.proceed()
        XCTAssertEqual(wireframe.calls.last, "feeTooHigh")

        presenter.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 1)))
        presenter.didReceiveStashItem(result: .success(CovCUBFixture.stashItem(controller: "ctrl")))
        presenter.proceed()
        XCTAssertEqual(wireframe.calls.last, "missingController")

        presenter.didReceiveController(result: .success(try CovCUBFixture.account(for: chainAsset, wallet: wallet)))
        presenter.proceed()
        XCTAssertEqual(wireframe.calls.last, "proceed")
        XCTAssertEqual(wireframe.rebondAmounts, [2])
        guard case let .relaychain(variant) = wireframe.rebondFlows.last, case let .custom(amount) = variant else {
            return XCTFail("expected a custom rebond flow")
        }
        XCTAssertEqual(amount, 2)

        presenter.close()
        XCTAssertEqual(wireframe.calls.last, "close")
    }
}
