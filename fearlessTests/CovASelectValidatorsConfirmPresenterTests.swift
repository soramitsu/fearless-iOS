import BigInt
import RobinHood
import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovAConfirmViewStub: UIViewController, SelectValidatorsConfirmViewProtocol {
    private(set) var presentedControllers: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
        completion?()
    }

    private(set) var confirmations: [LocalizableResource<SelectValidatorsConfirmViewModel>] = []
    private(set) var hints: [LocalizableResource<[TitleIconViewModel]>] = []
    private(set) var assets: [LocalizableResource<AssetBalanceViewModelProtocol>] = []
    private(set) var fees: [LocalizableResource<BalanceViewModelProtocol>?] = []
    private(set) var loadingEvents: [Bool] = []

    func didReceive(confirmationViewModel: LocalizableResource<SelectValidatorsConfirmViewModel>) {
        confirmations.append(confirmationViewModel)
    }

    func didReceive(hintsViewModel: LocalizableResource<[TitleIconViewModel]>) {
        hints.append(hintsViewModel)
    }

    func didReceive(assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assets.append(assetViewModel)
    }

    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        fees.append(feeViewModel)
    }

    func didStartLoading() {
        loadingEvents.append(true)
    }

    func didStopLoading() {
        loadingEvents.append(false)
    }

    func applyLocalization() {}
}

final class CovAConfirmWireframeStub: SelectValidatorsConfirmWireframeProtocol {
    private(set) var events: [String] = []
    private(set) var accountAddresses: [String] = []
    private(set) var completedHashes: [String] = []

    func complete(chainAsset _: ChainAsset, txHash: String, from _: SelectValidatorsConfirmViewProtocol?) {
        completedHashes.append(txHash)
    }

    func presentAccountOptions(
        from _: ControllerBackedProtocol,
        address: String,
        chain _: ChainModel,
        locale _: Locale,
        exportClosure _: (() -> Void)?
    ) {
        accountAddresses.append(address)
    }

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        events.append("error")
        return false
    }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        events.append("sheet:\(viewModel.title)")
    }

    func present(
        message _: String?,
        title: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        events.append("message:\(title)")
    }

    func presentAmountTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {
        events.append("amountTooHigh")
    }

    func presentFeeNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) {
        events.append("feeNotReceived")
    }

    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) {
        events.append("extrinsicFailed")
    }

    func presentMissingController(from _: ControllerBackedProtocol, address: AccountAddress, locale _: Locale?) {
        events.append("missingController:\(address)")
    }
}

final class CovAConfirmInteractorSpy: SelectValidatorsConfirmInteractorInputProtocol {
    private(set) var setupCount = 0
    private(set) var feeClosures: [ExtrinsicBuilderClosure?] = []
    private(set) var submitClosures: [ExtrinsicBuilderClosure?] = []

    func setup() {
        setupCount += 1
    }

    func submitNomination(closure: ExtrinsicBuilderClosure?) {
        submitClosures.append(closure)
    }

    func estimateFee(closure: ExtrinsicBuilderClosure?) {
        feeClosures.append(closure)
    }
}

final class CovAConfirmPresenterSpy: SelectValidatorsConfirmPresenterProtocol {
    private(set) var calls: [String] = []

    func setup() {
        calls.append("setup")
    }

    func selectWalletAccount() {
        calls.append("wallet")
    }

    func selectPayoutAccount() {
        calls.append("payout")
    }

    func proceed() {
        calls.append("proceed")
    }
}

final class CovASelectValidatorsConfirmPresenterTests: XCTestCase {
    private struct CovAContext {
        let presenter: SelectValidatorsConfirmPresenter
        let view: CovAConfirmViewStub
        let wireframe: CovAConfirmWireframeStub
        let interactor: CovAConfirmInteractorSpy
        let state: SelectValidatorsConfirmRelaychainInitiatedViewModelState
    }

    private func makeContext(amount: Decimal = 1) -> CovAContext {
        let wireframe = CovAConfirmWireframeStub()
        let interactor = CovAConfirmInteractorSpy()
        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        let state = SelectValidatorsConfirmRelaychainInitiatedViewModelState(
            targets: CovAConfirmFixtures.targets,
            maxTargets: 16,
            initiatedBonding: CovAConfirmFixtures.initiated(payout: true, amount: amount),
            chainAsset: CovAConfirmFixtures.chainAsset,
            wallet: CovAConfirmFixtures.wallet,
            dataValidatingFactory: dataValidatingFactory,
            callFactory: CovAConfirmFixtures.callFactory()
        )
        let presenter = SelectValidatorsConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: CovAConfirmFixtures.factories()[0],
            viewModelState: state,
            dataValidatingFactory: dataValidatingFactory,
            chainAsset: CovAConfirmFixtures.chainAsset,
            wallet: CovAConfirmFixtures.wallet,
            logger: Logger.shared,
            submissionAuthorizer: GrantingSubmissionAuthorizer()
        )
        let view = CovAConfirmViewStub()
        view.localizationManager = CovAFixtures.localizationManager
        view.loadViewIfNeeded()
        presenter.view = view
        dataValidatingFactory.view = view
        return CovAContext(presenter: presenter, view: view, wireframe: wireframe, interactor: interactor, state: state)
    }

    func testSetupEstimatesFeeAndRendersStateUpdates() {
        let context = makeContext()
        context.presenter.setup()
        XCTAssertEqual(context.interactor.setupCount, 1)
        XCTAssertEqual(context.interactor.feeClosures.count, 1)
        XCTAssertNotNil(context.interactor.feeClosures.first ?? nil)
        XCTAssertEqual(context.view.fees.count, 1)
        XCTAssertNil(context.view.fees.first ?? nil, "no fee is known before the estimate")

        context.state.didSetup()
        context.state.didReceiveStakingDuration(result: .success(CovAConfirmFixtures.duration))
        context.state.didReceive(paymentInfo: RuntimeDispatchInfo(feeValue: BigUInt(10_000_000_000)))
        context.presenter.didReceiveAccountInfo(result: .success(WestendStub.accountInfo.item))

        XCTAssertEqual(context.view.confirmations.count, 1)
        XCTAssertEqual(context.view.confirmations.first?.value(for: CovAFixtures.locale).senderName, "Cov wallet")
        XCTAssertEqual(context.view.hints.count, 1)
        XCTAssertNotNil(context.view.fees.last ?? nil)
        XCTAssertEqual(context.view.assets.count, 2)
        XCTAssertEqual(context.presenter.balance, 10)

        context.presenter.didReceiveAccountInfo(result: .success(nil))
        XCTAssertEqual(context.presenter.balance, 0)
        context.presenter.feeParametersUpdated()
        XCTAssertEqual(context.interactor.feeClosures.count, 2)
    }

    func testAccountSelectionsOpenAccountOptions() {
        let context = makeContext()
        context.presenter.selectWalletAccount()
        context.presenter.selectPayoutAccount()
        XCTAssertEqual(context.view.presentedControllers.count, 2, "wallet and payout address options")
        XCTAssertTrue(context.view.presentedControllers.allSatisfy { $0 is UIAlertController })

        let restake = SelectValidatorsConfirmPresenter(
            interactor: CovAConfirmInteractorSpy(),
            wireframe: context.wireframe,
            viewModelFactory: CovAConfirmFixtures.factories()[0],
            viewModelState: CovAConfirmFixtures.relaychainInitiated(payout: false),
            dataValidatingFactory: StakingDataValidatingFactory(presentable: context.wireframe),
            chainAsset: CovAConfirmFixtures.chainAsset,
            wallet: CovAConfirmFixtures.wallet
        )
        restake.view = context.view
        restake.selectPayoutAccount()
        XCTAssertEqual(context.view.presentedControllers.count, 2, "restake has no payout account")
        restake.view = nil
        restake.selectWalletAccount()
    }

    func testProceedSubmitsWhenValidationsPass() {
        let context = makeContext(amount: 1)
        context.presenter.setup()
        context.state.didReceive(paymentInfo: RuntimeDispatchInfo(feeValue: BigUInt(10_000_000_000)))
        context.state.didReceiveAccountInfo(result: .success(WestendStub.accountInfo.item))
        context.presenter.proceed()
        CovAViewInspector.spin(until: { !context.interactor.submitClosures.isEmpty }, timeout: 2)
        XCTAssertEqual(context.interactor.submitClosures.count, 1)
        XCTAssertNotNil(context.interactor.submitClosures.first ?? nil)
    }

    func testProceedStopsWhenFundsAreShort() {
        let context = makeContext(amount: 50)
        context.presenter.setup()
        context.state.didReceive(paymentInfo: RuntimeDispatchInfo(feeValue: BigUInt(10_000_000_000)))
        context.state.didReceiveAccountInfo(result: .success(WestendStub.accountInfo.item))
        context.presenter.proceed()
        XCTAssertTrue(context.interactor.submitClosures.isEmpty)
        XCTAssertFalse(context.wireframe.events.isEmpty && context.view.presentedControllers.isEmpty, "a warning is shown")
    }

    func testNominationLifecycleAndErrors() {
        let context = makeContext()
        context.presenter.didStartNomination()
        context.presenter.didCompleteNomination(txHash: "0x01")
        context.presenter.didFailNomination(error: SelectValidatorsConfirmError.extrinsicFailed)
        context.presenter.didReceiveError(error: SelectValidatorsConfirmError.notEnoughFunds)
        context.presenter.didReceiveError(error: SelectValidatorsConfirmError.feeNotReceived)
        context.presenter.didReceiveError(error: SelectValidatorsConfirmError.missingController(address: "ctrl"))
        context.presenter.didReceiveError(error: CovATestError.failed)
        context.presenter.didReceiveAccountInfo(result: .failure(CovATestError.failed))

        XCTAssertEqual(context.view.loadingEvents, [true, false, false])
        XCTAssertEqual(context.wireframe.completedHashes, ["0x01"])
        XCTAssertEqual(context.wireframe.events, [
            "extrinsicFailed", "amountTooHigh", "feeNotReceived", "missingController:ctrl", "error", "error"
        ])

        context.presenter.view = nil
        context.presenter.didReceiveError(error: SelectValidatorsConfirmError.notEnoughFunds)
        XCTAssertEqual(context.wireframe.events.count, 6, "typed errors need a view")
    }

    // MARK: - Interactor

    func testInteractorBaseForwardsToStrategyAndBalanceUpdates() {
        final class CovAConfirmStrategySpy: SelectValidatorsConfirmStrategy {
            var calls: [String] = []
            func setup() {
                calls.append("setup")
            }

            func estimateFee(closure _: ExtrinsicBuilderClosure?) {
                calls.append("fee")
            }

            func submitNomination(closure _: ExtrinsicBuilderClosure?) {
                calls.append("submit")
            }

            func subscribeToBalance() {
                calls.append("balance")
            }
        }
        final class CovAConfirmOutputSpy: SelectValidatorsConfirmInteractorOutputProtocol {
            var results: [Result<AccountInfo?, Error>] = []
            func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
                results.append(result)
            }
        }
        let strategy = CovAConfirmStrategySpy()
        let output = CovAConfirmOutputSpy()
        let adapter = CovAAccountInfoAdapterStub()
        let interactor = SelectValidatorsConfirmInteractorBase(
            balanceAccountId: CovAFixtures.accountId(7),
            chainAsset: CovAConfirmFixtures.chainAsset,
            strategy: strategy,
            accountInfoSubscriptionAdapter: adapter
        )
        interactor.presenter = output
        interactor.setup()
        interactor.estimateFee(closure: nil)
        interactor.submitNomination(closure: nil)
        interactor.handleAccountInfo(
            result: .success(nil),
            accountId: CovAFixtures.accountId(7),
            chainAsset: CovAConfirmFixtures.chainAsset
        )
        XCTAssertEqual(strategy.calls, ["setup", "balance", "fee", "submit"])
        XCTAssertEqual(adapter.subscribedAccountIds, [CovAFixtures.accountId(7)])
        XCTAssertEqual(output.results.count, 1)
    }

    // MARK: - View controller

    func testViewControllerAppliesViewModelsAndRoutesActions() throws {
        let presenter = CovAConfirmPresenterSpy()
        let controller = SelectValidatorsConfirmViewController(
            presenter: presenter,
            quantityFormatter: NumberFormatter.quantity.localizableResource().value(for: CovAFixtures.locale),
            localizationManager: CovAFixtures.localizationManager
        )
        let window = CovAViewInspector.host(controller)
        XCTAssertEqual(presenter.calls, ["setup"])
        XCTAssertFalse(controller.rootView.networkFeeFooterView.actionButton.isEnabled)

        let payout = SelectValidatorsConfirmViewModel(
            senderAddress: CovAFixtures.address(7),
            senderName: "Cov wallet",
            amount: BalanceViewModel(amount: "1 COV", price: "$2"),
            rewardDestination: .payout(icon: nil, title: "Payout", address: CovAFixtures.address(9)),
            validatorsCount: 2,
            maxValidatorCount: 16,
            stakeAmountViewModel: nil,
            poolName: nil
        )
        controller.didReceive(confirmationViewModel: LocalizableResource { _ in payout })
        XCTAssertEqual(controller.rootView.amountView.valueTop.text, "1 COV")
        XCTAssertEqual(controller.rootView.mainAccountView.valueTop.text, "Cov wallet")
        XCTAssertEqual(controller.rootView.payoutAccountView?.valueTop.text, "Payout")
        XCTAssertEqual(controller.rootView.payoutAccountView?.valueBottom.text, CovAFixtures.address(9))
        XCTAssertTrue(controller.rootView.poolView.isHidden)
        XCTAssertTrue(try XCTUnwrap(controller.rootView.validatorsView.valueLabel.text).contains("16"))

        let pool = SelectValidatorsConfirmViewModel(
            senderAddress: nil, senderName: "Pool member", amount: nil, rewardDestination: nil,
            validatorsCount: nil, maxValidatorCount: nil, stakeAmountViewModel: nil, poolName: "Pool Three"
        )
        controller.didReceive(confirmationViewModel: LocalizableResource { _ in pool })
        XCTAssertFalse(controller.rootView.poolView.isHidden)
        XCTAssertEqual(controller.rootView.poolView.valueTop.text, "Pool Three")
        XCTAssertTrue(controller.rootView.amountView.isHidden)
        XCTAssertTrue(controller.rootView.validatorsView.isHidden)

        let restake = SelectValidatorsConfirmViewModel(
            senderAddress: nil, senderName: "Restaker", amount: nil, rewardDestination: .restake,
            validatorsCount: 1, maxValidatorCount: 16, stakeAmountViewModel: nil, poolName: nil
        )
        controller.didReceive(confirmationViewModel: LocalizableResource { _ in restake })
        XCTAssertNil(controller.rootView.payoutAccountView)
        XCTAssertEqual(
            controller.rootView.rewardDestinationView.valueTop.text,
            R.string.localizable.stakingRestakeTitle(preferredLanguages: ["en"])
        )

        let hints = [TitleIconViewModel(title: "Hint one", icon: nil), TitleIconViewModel(title: "Hint two", icon: nil)]
        controller.didReceive(hintsViewModel: LocalizableResource { _ in hints })
        XCTAssertEqual(controller.rootView.hintViews.count, 2)

        controller.didReceive(feeViewModel: LocalizableResource { _ in BalanceViewModel(amount: "0.01 COV", price: nil) })
        controller.didReceive(assetViewModel: LocalizableResource { _ in
            AssetBalanceViewModel(symbol: "COV", balance: "10", fiatBalance: nil, price: nil, iconViewModel: nil, selectable: false)
        })
        XCTAssertTrue(controller.rootView.networkFeeFooterView.actionButton.isEnabled)
        XCTAssertTrue(CovAViewInspector.contains("0.01 COV", in: controller.view))

        controller.rootView.networkFeeFooterView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.calls.last, "proceed")

        controller.applyLocalization()
        XCTAssertEqual(controller.title, R.string.localizable.commonConfirmTitle(preferredLanguages: ["en"]))
        controller.didReachTransferStage(.signed)
        controller.didBreakTransfer()
        window.isHidden = true
    }
}
