import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovAValidatorInfoInteractorSpy: ValidatorInfoInteractorInputProtocol {
    private(set) var setupCount = 0
    private(set) var reloadCount = 0

    func setup() {
        setupCount += 1
    }

    func reload() {
        reloadCount += 1
    }
}

final class CovAValidatorInfoPresenterTests: XCTestCase {
    private struct CovAContext {
        let presenter: ValidatorInfoPresenter
        let view: CovAValidatorInfoViewStub
        let wireframe: CovAValidatorInfoWireframeStub
        let interactor: CovAValidatorInfoInteractorSpy
        let state: ValidatorInfoRelaychainViewModelState
    }

    private func makeContext() -> CovAContext {
        let chainAsset = CovAFixtures.chainAsset()
        let wallet = CovAFixtures.wallet()
        let state = ValidatorInfoRelaychainViewModelState()
        let interactor = CovAValidatorInfoInteractorSpy()
        let wireframe = CovAValidatorInfoWireframeStub()
        let presenter = ValidatorInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: ValidatorInfoRelaychainViewModelFactory(
                iconGenerator: UniversalIconGenerator(),
                balanceViewModelFactory: CovAFixtures.balanceFactory(chainAsset: chainAsset, wallet: wallet)
            ),
            viewModelState: state,
            chainAsset: chainAsset,
            wallet: wallet,
            localizationManager: CovAFixtures.localizationManager,
            logger: Logger.shared
        )
        let view = CovAValidatorInfoViewStub()
        view.loadViewIfNeeded()
        presenter.view = view
        return CovAContext(presenter: presenter, view: view, wireframe: wireframe, interactor: interactor, state: state)
    }

    func testSetupLoadsAndRendersValidator() {
        let context = makeContext()
        context.presenter.setup()
        XCTAssertEqual(context.interactor.setupCount, 1)

        context.state.didStartLoading()
        context.state.didReceiveValidatorInfo(CovAFixtures.validator(1, identity: CovAFixtures.identity()))
        context.state.didReceiveError(CovATestError.failed)
        context.presenter.reload()

        XCTAssertEqual(context.interactor.reloadCount, 1)
        XCTAssertEqual(context.view.states.count, 2)
        guard case .loading = context.view.states[0] else { return XCTFail("loading first") }
        guard case let .validatorInfo(viewModel) = context.view.states[1] else { return XCTFail("then info") }
        XCTAssertEqual(viewModel.account.name, "Validator One")
    }

    func testEmptyStateWhenNothingIsKnown() {
        let context = makeContext()
        context.presenter.setup()
        context.presenter.modelStateDidChanged(viewModelState: context.state)
        guard case .empty = context.view.states.last else { return XCTFail("expected empty") }
        context.presenter.presentTotalStake()
        context.presenter.presentAccountOptions()
        context.presenter.presentMinStake()
        XCTAssertTrue(context.wireframe.stakingAmounts.isEmpty)
        XCTAssertTrue(context.wireframe.accountOptionAddresses.isEmpty)
        XCTAssertTrue(context.wireframe.infos.isEmpty)
    }

    func testAccountOptionsTotalStakeAndMinStakeRoutes() throws {
        let context = makeContext()
        context.presenter.setup()
        let validator = CovAFixtures.validator(2)
        context.state.didReceiveValidatorInfo(validator)

        context.presenter.presentAccountOptions()
        XCTAssertTrue(context.view.presentedControllers.last is UIAlertController, "the address options sheet is shown")
        context.presenter.presentTotalStake()
        context.presenter.presentMinStake()

        XCTAssertEqual(context.wireframe.stakingAmounts.first?.count, 3)
        let info = try XCTUnwrap(context.wireframe.infos.first ?? nil)
        XCTAssertTrue(info.contains("20"), info)
    }

    func testIdentityLinksOpenTheRightDestinations() {
        let context = makeContext()
        context.presenter.presentIdentityItem(.text("plain"))
        context.presenter.presentIdentityItem(.link("https://validator.example", tag: .web))
        context.presenter.presentIdentityItem(.link("@validator:matrix.org", tag: .riot))
        context.presenter.presentIdentityItem(.link("validator", tag: .twitter))
        context.presenter.presentIdentityItem(.link("validator@example.com", tag: .email))
        context.wireframe.emailResult = true
        context.presenter.presentIdentityItem(.link("second@example.com", tag: .email))

        XCTAssertEqual(context.wireframe.webURLs.map(\.absoluteString), [
            "https://validator.example",
            "https://matrix.to/#/@validator:matrix.org",
            "https://twitter.com/validator"
        ])
        XCTAssertEqual(context.wireframe.emails.map(\.recepients), [["validator@example.com"], ["second@example.com"]])
        XCTAssertEqual(context.view.presentedControllers.count, 1, "only a failed email composer shows an error")
        XCTAssertTrue(context.view.presentedControllers.first is SheetAletViewController)
    }

    func testLocalizationRefreshesALoadedView() {
        let context = makeContext()
        context.state.didReceiveValidatorInfo(CovAFixtures.validator(3, stakeInfo: nil))
        context.presenter.applyLocalization()
        guard case let .validatorInfo(viewModel) = context.view.states.last else { return XCTFail("expected info") }
        guard case .unelected = viewModel.staking.status else { return XCTFail("expected unelected") }
    }

    func testWithoutViewNothingIsPresented() {
        let context = makeContext()
        context.presenter.view = nil
        context.presenter.activateEmail("x@example.com")
        context.presenter.presentIdentityItem(.link("https://validator.example", tag: .web))
        XCTAssertTrue(context.wireframe.emails.isEmpty)
        XCTAssertTrue(context.wireframe.webURLs.isEmpty)
    }

    // MARK: - View controller

    private func electedViewModel(identity: Bool = true, slashed: Bool = true) throws -> ValidatorInfoViewModel {
        let validator = CovAFixtures.validator(
            4,
            identity: identity ? CovAFixtures.identity() : nil,
            myNomination: .active(allocation: ValidatorTokenAllocation(amount: 1, isRewarded: false)),
            hasSlashes: slashed
        )
        let state = ValidatorInfoRelaychainViewModelState()
        state.didReceiveValidatorInfo(validator)
        let factory = ValidatorInfoRelaychainViewModelFactory(
            iconGenerator: UniversalIconGenerator(),
            balanceViewModelFactory: CovAFixtures.balanceFactory()
        )
        return try XCTUnwrap(factory.buildViewModel(viewModelState: state, priceData: nil, locale: CovAFixtures.locale))
    }

    func testViewControllerRendersElectedValidatorAndRoutesTaps() throws {
        let presenter = CovAValidatorInfoPresenterSpy()
        let controller = ValidatorInfoViewController(presenter: presenter, localizationManager: CovAFixtures.localizationManager)
        let window = CovAViewInspector.host(controller)
        XCTAssertEqual(presenter.calls, ["setup"])

        let viewModel = try electedViewModel()
        controller.didRecieve(state: .validatorInfo(viewModel))
        controller.view.layoutIfNeeded()

        XCTAssertFalse(controller.rootView.contentView.isHidden)
        XCTAssertEqual(controller.title, viewModel.title)
        let labels = CovAViewInspector.labels(in: controller.view)
        XCTAssertTrue(labels.contains("Validator One"))
        XCTAssertTrue(labels.contains("Legal Name"))
        XCTAssertTrue(labels.contains(R.string.localizable.stakingValidatorStatusElected(preferredLanguages: ["en"])))
        XCTAssertTrue(labels.contains(R.string.localizable.stakingValidatorSlashedDesc(preferredLanguages: ["en"])))
        XCTAssertTrue(labels.contains(R.string.localizable.stakingValidatorMyOversubscribedMessage(preferredLanguages: ["en"])))

        for subview in CovAViewInspector.subviews(of: DetailsTriangularedView.self, in: controller.view) {
            subview.sendActions(for: .touchUpInside)
        }
        CovAViewInspector.subviews(of: UIControl.self, in: controller.view)
            .filter { !($0 is DetailsTriangularedView) && !($0 is UIButton) }
            .forEach { $0.sendActions(for: .touchUpInside) }

        XCTAssertTrue(presenter.calls.contains("account"))
        XCTAssertTrue(presenter.calls.contains("total"))
        XCTAssertTrue(presenter.calls.contains("min"))
        XCTAssertEqual(presenter.identityValues.count, 4, "email, web, twitter and riot rows are links")
        controller.applyLocalization()
        window.isHidden = true
    }

    func testViewControllerRendersUnelectedAndStates() throws {
        let presenter = CovAValidatorInfoPresenterSpy()
        let controller = ValidatorInfoViewController(presenter: presenter, localizationManager: CovAFixtures.localizationManager)
        let window = CovAViewInspector.host(controller)

        let unelected = ValidatorInfoViewModel(
            account: AccountInfoViewModel(title: "", address: CovAFixtures.address(5), name: "", icon: nil),
            staking: .init(status: .unelected(commission: "5.00%"), slashed: false),
            identity: [],
            title: "Info"
        )
        controller.didRecieve(state: .validatorInfo(unelected))
        var labels = CovAViewInspector.labels(in: controller.view)
        XCTAssertTrue(labels.contains("5.00%"))
        XCTAssertTrue(labels.contains(CovAFixtures.address(5)))
        XCTAssertTrue(labels.contains(R.string.localizable.stakingValidatorStatusUnelected(preferredLanguages: ["en"])))

        controller.didRecieve(state: .loading)
        XCTAssertTrue(controller.rootView.contentView.isHidden)
        XCTAssertFalse(controller.shouldDisplayEmptyState)
        XCTAssertNil(controller.viewForEmptyState)

        controller.didRecieve(state: .empty)
        XCTAssertTrue(controller.rootView.contentView.isHidden)

        controller.didRecieve(state: .error("Broken"))
        XCTAssertTrue(controller.shouldDisplayEmptyState)
        let errorView = try XCTUnwrap(controller.viewForEmptyState as? ErrorStateView)
        XCTAssertEqual(errorView.errorDescriptionLabel.text, "Broken")
        controller.didRetry(errorView: errorView)
        XCTAssertEqual(presenter.calls.last, "reload")
        labels = CovAViewInspector.labels(in: controller.view)
        XCTAssertFalse(labels.isEmpty)
        window.isHidden = true
    }

    func testOversubscribedHintForOtherNominators() {
        let layout = ValidatorInfoViewLayout()
        let exposure = ValidatorInfoViewModel.Exposure(
            nominators: "3 of 2",
            myNomination: nil,
            totalStake: BalanceViewModel(amount: "100 COV", price: "$1"),
            estimatedReward: "15%",
            oversubscribed: true,
            comission: "5%",
            minStakeToGetRewards: nil
        )
        layout.addNominatorsView(exposure, locale: CovAFixtures.locale)
        layout.addBalanceView(title: "Plain", viewModel: exposure.totalStake, clickable: false)
        let labels = CovAViewInspector.labels(in: layout)
        XCTAssertTrue(labels.contains(R.string.localizable.stakingValidatorOtherOversubscribedMessage(preferredLanguages: ["en"])))
        XCTAssertTrue(labels.contains("Plain"))
        XCTAssertTrue(labels.contains("100 COV"))
        layout.clearStackView()
        XCTAssertTrue(layout.stackView.arrangedSubviews.isEmpty)
    }

    func testWireframePresentsStakingAmountsPicker() throws {
        let host = CovAValidatorInfoViewStub()
        let factory = ValidatorInfoRelaychainViewModelFactory(
            iconGenerator: UniversalIconGenerator(),
            balanceViewModelFactory: CovAFixtures.balanceFactory()
        )
        let state = ValidatorInfoRelaychainViewModelState()
        state.didReceiveValidatorInfo(CovAFixtures.validator(6))
        let items = try XCTUnwrap(factory.buildStakingAmountViewModels(viewModelState: state, priceData: nil))
        ValidatorInfoWireframe().showStakingAmounts(from: host, items: items)
        XCTAssertEqual(host.presentedControllers.count, 1, "the staking amounts picker is presented")
    }
}
