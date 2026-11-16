import RobinHood
import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovAStartListenerSpy: SelectValidatorsStartModelStateListener {
    private(set) var changes = 0
    private(set) var errors = 0
    func modelStateDidChanged(viewModelState _: SelectValidatorsStartViewModelState) {
        changes += 1
    }

    func didReceiveError(error _: Error) {
        errors += 1
    }
}

final class CovAStartViewStub: UIViewController, SelectValidatorsStartViewProtocol {
    private(set) var viewModels: [SelectValidatorsStartViewModel?] = []
    private(set) var texts: [SelectValidatorsStartTextsViewModel] = []
    private(set) var loading: [Bool] = []

    func didReceive(viewModel: SelectValidatorsStartViewModel?) {
        viewModels.append(viewModel)
    }

    func didReceive(textsViewModel: SelectValidatorsStartTextsViewModel) {
        texts.append(textsViewModel)
    }

    func didStartLoading() {
        loading.append(true)
    }

    func didStopLoading() {
        loading.append(false)
    }

    func applyLocalization() {}
}

final class CovAStartWireframeStub: SelectValidatorsStartWireframeProtocol {
    private(set) var customFlows: [CustomValidatorListFlow] = []
    private(set) var recommendedFlows: [RecommendedValidatorListFlow] = []
    private(set) var errors: [Error] = []
    private(set) var actions: [[SheetAlertPresentableAction]] = []

    func proceedToCustomList(from _: ControllerBackedProtocol?, flow: CustomValidatorListFlow, chainAsset _: ChainAsset, wallet _: MetaAccountModel) {
        customFlows.append(flow)
    }

    func proceedToRecommendedList(
        from _: SelectValidatorsStartViewProtocol?,
        flow: RecommendedValidatorListFlow,
        wallet _: MetaAccountModel,
        chainAsset _: ChainAsset
    ) {
        recommendedFlows.append(flow)
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return false
    }

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions: [SheetAlertPresentableAction]
    ) {
        self.actions.append(actions)
    }
}

final class CovAStartPresenterSpy: SelectValidatorsStartPresenterProtocol {
    private(set) var calls: [String] = []
    func setup() {
        calls.append("setup")
    }

    func updateOnAppearance() {
        calls.append("appear")
    }

    func selectRecommendedValidators() {
        calls.append("recommended")
    }

    func selectCustomValidators() {
        calls.append("custom")
    }
}

final class CovAStartInteractorSpy: SelectValidatorsStartInteractorInputProtocol {
    private(set) var setups = 0
    func setup() {
        setups += 1
    }
}

final class CovASelectValidatorsStartTests: XCTestCase {
    private func elected() -> [ElectedValidatorInfo] {
        [
            CovAFixtures.electedValidator(1, identity: CovAFixtures.identity(name: "E1"), stakeReturn: 0.3),
            CovAFixtures.electedValidator(2, identity: CovAFixtures.identity(name: "E2"), stakeReturn: 0.2),
            CovAFixtures.electedValidator(3, stakeReturn: 0.1)
        ]
    }

    private func states() -> [SelectValidatorsStartViewModelState] {
        let targets = [CovAFixtures.validator(2), CovAFixtures.validator(40)]
        return [
            SelectValidatorsStartRelaychainInitiatedViewModelState(
                bonding: CovAConfirmFixtures.initiated(payout: false), initialTargets: nil, existingStashAddress: nil
            ),
            SelectValidatorsStartRelaychainExistingViewModelState(
                bonding: CovAConfirmFixtures.existing(payout: true), initialTargets: targets, existingStashAddress: CovAFixtures.address(7)
            ),
            SelectValidatorsStartPoolInitiatedViewModelState(
                poolId: 4, bonding: CovAConfirmFixtures.initiated(payout: false), initialTargets: nil, existingStashAddress: nil
            ),
            SelectValidatorsStartPoolExistingViewModelState(
                poolId: 5, bonding: CovAConfirmFixtures.existing(payout: false), initialTargets: targets,
                existingStashAddress: CovAFixtures.address(7)
            )
        ]
    }

    private func factories() -> [SelectValidatorsStartViewModelFactoryProtocol] {
        [
            SelectValidatorsStartRelaychainViewModelFactory(),
            SelectValidatorsStartRelaychainViewModelFactory(),
            SelectValidatorsStartPoolInitiatedViewModelFactory(),
            SelectValidatorsStartPoolExistingViewModelFactory()
        ]
    }

    private func feed(_ state: SelectValidatorsStartViewModelState, validators: [ElectedValidatorInfo], max: Int) {
        if let relay = state as? SelectValidatorsStartRelaychainViewModelState {
            relay.didReceiveMaxNominations(result: .success(max))
            relay.didReceiveValidators(result: .success(validators))
        } else if let pool = state as? SelectValidatorsStartPoolViewModelState {
            pool.didReceiveMaxNominations(result: .success(max))
            pool.didReceiveValidators(result: .success(validators))
        }
    }

    func testStatesComposeRecommendedAndCustomFlows() throws {
        for (index, state) in states().enumerated() {
            let listener = CovAStartListenerSpy()
            state.setStateListener(listener)
            XCTAssertNil(state.customValidatorListFlow)
            XCTAssertThrowsError(try state.recommendedValidatorListFlow())

            feed(state, validators: elected(), max: 2)
            XCTAssertEqual(listener.changes, 2)

            switch try (index, XCTUnwrap(state.customValidatorListFlow)) {
            case let (0, .relaychainInitiated(list, recommended, selected, maxTargets, _)):
                XCTAssertEqual(list.count, 3)
                XCTAssertEqual(recommended.count, 2)
                XCTAssertEqual(selected.count, 0)
                XCTAssertEqual(maxTargets, 2)
            case let (1, .relaychainExisting(_, _, selected, _, _)):
                XCTAssertEqual(selected.items.map(\.address), [CovAFixtures.address(2), CovAFixtures.address(40)])
            case let (2, .poolInitiated(_, _, _, poolId, _, _)):
                XCTAssertEqual(poolId, 4)
            case let (3, .poolExisting(_, _, selected, poolId, _, _)):
                XCTAssertEqual(poolId, 5)
                XCTAssertEqual(selected.count, 2)
            default:
                XCTFail("unexpected custom flow at \(index)")
            }

            switch try (index, XCTUnwrap(try state.recommendedValidatorListFlow())) {
            case let (0, .relaychainInitiated(validators, maxTargets, _)):
                XCTAssertEqual(validators.map(\.address), [CovAFixtures.address(1), CovAFixtures.address(2)])
                XCTAssertEqual(maxTargets, 2)
            case let (1, .relaychainExisting(validators, _, _)):
                XCTAssertEqual(validators.count, 2)
            case let (2, .poolInitiated(poolId, _, _, _)):
                XCTAssertEqual(poolId, 4)
            case let (3, .poolExisting(poolId, _, _, _)):
                XCTAssertEqual(poolId, 5)
            default:
                XCTFail("unexpected recommended flow at \(index)")
            }

            let viewModel = try XCTUnwrap(factories()[index].buildViewModel(viewModelState: state))
            XCTAssertEqual(viewModel, SelectValidatorsStartViewModel(selectedCount: 3, totalCount: 2, recommendedValidatorListLoaded: true))
            let texts = try XCTUnwrap(factories()[index].buildTextsViewModel(locale: CovAFixtures.locale))
            XCTAssertEqual(texts.algoSteps.count, 5)
            XCTAssertFalse(texts.customValidatorsSectionLabel.isEmpty)
        }
    }

    func testStatesReportFailures() {
        for state in states() {
            let listener = CovAStartListenerSpy()
            state.setStateListener(listener)
            if let relay = state as? SelectValidatorsStartRelaychainViewModelState {
                relay.didReceiveValidators(result: .failure(CovATestError.failed))
                relay.didReceiveMaxNominations(result: .failure(CovATestError.failed))
            } else if let pool = state as? SelectValidatorsStartPoolViewModelState {
                pool.didReceiveValidators(result: .failure(CovATestError.failed))
                pool.didReceiveMaxNominations(result: .failure(CovATestError.failed))
            }
            XCTAssertEqual(listener.errors, 2)
            XCTAssertEqual(listener.changes, 0)
        }
    }

    func testFactoriesRejectForeignStates() {
        let allStates = states()
        XCTAssertNil(SelectValidatorsStartRelaychainViewModelFactory().buildViewModel(viewModelState: allStates[2]))
        XCTAssertNil(SelectValidatorsStartPoolInitiatedViewModelFactory().buildViewModel(viewModelState: allStates[3]))
        XCTAssertNil(SelectValidatorsStartPoolExistingViewModelFactory().buildViewModel(viewModelState: allStates[0]))
        XCTAssertNil(SelectValidatorsStartRelaychainViewModelFactory().buildViewModel(viewModelState: allStates[0]))
        XCTAssertNotNil(SelectValidatorsStartPoolExistingViewModelFactory().buildTextsViewModel(locale: CovAFixtures.locale))
    }

    func testStrategiesDeliverValidatorsAndConstantFailure() {
        let relayState = states()[0] as? SelectValidatorsStartRelaychainViewModelState
        let poolState = states()[2] as? SelectValidatorsStartPoolViewModelState
        let relayListener = CovAStartListenerSpy()
        let poolListener = CovAStartListenerSpy()
        relayState?.setStateListener(relayListener)
        poolState?.setStateListener(poolListener)
        let operationFactory = CovAValidatorOperationFactoryStub()
        operationFactory.electedResult = elected()

        let relayStrategy = SelectValidatorsStartRelaychainStrategy(
            operationFactory: operationFactory, operationManager: OperationManager(),
            runtimeService: CovARuntimeCodingServiceStub(), output: relayState
        )
        let poolStrategy = SelectValidatorsStartPoolStrategy(
            operationFactory: operationFactory, operationManager: OperationManager(),
            runtimeService: CovARuntimeCodingServiceStub(), output: poolState
        )
        relayStrategy.setup()
        poolStrategy.setup()
        CovAViewInspector.spin(until: {
            relayListener.changes + relayListener.errors >= 2 && poolListener.changes + poolListener.errors >= 2
        })
        XCTAssertEqual(relayListener.changes, 1)
        XCTAssertEqual(relayListener.errors, 1, "the max nominations constant cannot be read")
        XCTAssertEqual(poolListener.changes, 1)
        XCTAssertEqual(poolListener.errors, 1)
        XCTAssertEqual(relayState?.electedValidators?.count, 3)
        XCTAssertNil(relayState?.recommendedValidators, "nothing is recommended without the nomination limit")
    }

    func testPresenterDrivesLoadingAndRouting() throws {
        let state = states()[1]
        let wireframe = CovAStartWireframeStub()
        let interactor = CovAStartInteractorSpy()
        let presenter = SelectValidatorsStartPresenter(
            interactor: interactor,
            wireframe: wireframe,
            logger: Logger.shared,
            chainAsset: CovAFixtures.chainAsset(),
            wallet: CovAFixtures.wallet(),
            viewModelState: state,
            viewModelFactory: SelectValidatorsStartRelaychainViewModelFactory()
        )
        let view = CovAStartViewStub()
        view.localizationManager = CovAFixtures.localizationManager
        view.loadViewIfNeeded()
        presenter.view = view

        presenter.setup()
        XCTAssertEqual(interactor.setups, 1)
        XCTAssertEqual(view.texts.count, 1)
        XCTAssertEqual(view.loading, [true])

        presenter.selectCustomValidators()
        XCTAssertTrue(wireframe.customFlows.isEmpty)
        presenter.selectRecommendedValidators()
        try XCTUnwrap(wireframe.actions.last?.first).handler?()
        XCTAssertEqual(wireframe.errors.count, 1, "recommended list is not loaded yet")

        feed(state, validators: elected(), max: 2)
        XCTAssertEqual(view.loading, [true, false])
        XCTAssertNotNil(view.viewModels.last ?? nil)

        presenter.selectCustomValidators()
        XCTAssertEqual(wireframe.customFlows.count, 1)
        presenter.selectRecommendedValidators()
        try XCTUnwrap(wireframe.actions.last?.first).handler?()
        XCTAssertEqual(wireframe.recommendedFlows.count, 1)

        presenter.updateOnAppearance()
        presenter.didReceiveError(error: CovATestError.failed)
        XCTAssertEqual(wireframe.errors.count, 3, "an unpresentable error falls back to a generic one")
    }

    func testViewControllerReflectsLoadingAndForwardsActions() throws {
        for phase in [SelectValidatorsStartViewController.Phase.setup, .update] {
            let presenter = CovAStartPresenterSpy()
            let controller = SelectValidatorsStartViewController(
                presenter: presenter, phase: phase, localizationManager: CovAFixtures.localizationManager
            )
            let window = CovAViewInspector.host(UINavigationController(rootViewController: controller))
            controller.beginAppearanceTransition(true, animated: false)
            controller.endAppearanceTransition()
            XCTAssertEqual(presenter.calls.first, "setup")
            XCTAssertTrue(presenter.calls.contains("appear"))
            XCTAssertFalse(controller.rootView.recommendedValidatorsButton.isEnabled)

            let texts = try XCTUnwrap(SelectValidatorsStartRelaychainViewModelFactory().buildTextsViewModel(locale: CovAFixtures.locale))
            controller.didReceive(textsViewModel: texts)
            XCTAssertEqual(controller.rootView.algoSteps.count, 5)
            XCTAssertEqual(controller.rootView.algoSectionLabel.text, texts.algoSectionLabel)

            controller.rootView.recommendedValidatorsButton.sendActions(for: .touchUpInside)
            XCTAssertFalse(presenter.calls.contains("recommended"), "the list is not loaded yet")

            controller.didReceive(viewModel: SelectValidatorsStartViewModel(
                selectedCount: 1, totalCount: 16, recommendedValidatorListLoaded: true
            ))
            CovAViewInspector.spin(until: { controller.rootView.recommendedValidatorsButton.isEnabled }, timeout: 2)
            XCTAssertTrue(controller.rootView.recommendedValidatorsButton.isEnabled)
            XCTAssertTrue(controller.rootView.customValidatorsCell.isEnabled)
            controller.rootView.recommendedValidatorsButton.sendActions(for: .touchUpInside)
            controller.rootView.customValidatorsCell.sendActions(for: .touchUpInside)
            XCTAssertTrue(presenter.calls.contains("recommended"))
            XCTAssertTrue(presenter.calls.contains("custom"))
            controller.didReceive(viewModel: nil)
            controller.updateLoadingState()
            XCTAssertFalse(controller.rootView.customValidatorsCell.isEnabled)
            controller.applyLocalization()
            window.isHidden = true
        }
    }

    func testStartFlowPhases() {
        XCTAssertEqual(SelectValidatorsStartFlow.relaychainInitiated(state: CovAConfirmFixtures.initiated(payout: false)).phase, .setup)
        XCTAssertEqual(SelectValidatorsStartFlow.relaychainExisting(state: CovAConfirmFixtures.existing(payout: true)).phase, .update)
        XCTAssertEqual(
            SelectValidatorsStartFlow.relaychainExisting(state: CovAConfirmFixtures.existing(payout: true, nominated: false)).phase,
            .setup
        )
        XCTAssertEqual(SelectValidatorsStartFlow.poolInitiated(poolId: 1, state: CovAConfirmFixtures.initiated(payout: false)).phase, .setup)
        XCTAssertEqual(SelectValidatorsStartFlow.poolExisting(poolId: 1, state: CovAConfirmFixtures.existing(payout: false)).phase, .update)
        let content = SelectValidatorsStartError.dataNotLoaded.toErrorContent(for: CovAFixtures.locale)
        XCTAssertFalse(content.title.isEmpty)
        XCTAssertFalse(content.message.isEmpty)
    }
}
