import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovASelectedListDelegateSpy: SelectedValidatorListDelegate {
    private(set) var removedAddresses: [AccountAddress] = []
    private(set) var removed: [SelectedValidatorInfo] = []
    func didRemove(validatorAddress: AccountAddress) {
        removedAddresses.append(validatorAddress)
    }

    func didRemove(_ validator: SelectedValidatorInfo) {
        removed.append(validator)
    }
}

final class CovASelectedListViewStub: UIViewController, SelectedValidatorListViewProtocol {
    private(set) var reloads: [SelectedValidatorListViewModel] = []
    private(set) var removals: [Int] = []
    func didReload(_ viewModel: SelectedValidatorListViewModel) {
        reloads.append(viewModel)
    }

    func didChangeViewModel(_ viewModel: SelectedValidatorListViewModel, byRemovingItemAt index: Int) {
        reloads.append(viewModel)
        removals.append(index)
    }

    func applyLocalization() {}
}

final class CovASelectedListWireframeStub: SelectedValidatorListWireframeProtocol {
    private(set) var infoFlows: [ValidatorInfoFlow] = []
    private(set) var confirmFlows: [SelectValidatorsConfirmFlow] = []
    private(set) var dismissals = 0

    func present(flow: ValidatorInfoFlow, chainAsset _: ChainAsset, wallet _: MetaAccountModel, from _: ControllerBackedProtocol?) {
        infoFlows.append(flow)
    }

    func proceed(
        from _: SelectedValidatorListViewProtocol?,
        flow: SelectValidatorsConfirmFlow,
        wallet _: MetaAccountModel,
        chainAsset _: ChainAsset
    ) {
        confirmFlows.append(flow)
    }

    func dismiss(_: ControllerBackedProtocol?) {
        dismissals += 1
    }
}

final class CovASelectedValidatorListTests: XCTestCase {
    private let locale = CovAFixtures.locale

    private func validators() -> [SelectedValidatorInfo] {
        [
            CovAFixtures.validator(1, identity: CovAFixtures.identity(name: "One"), stakeInfo: CovAFixtures.stakeInfo(stakeReturn: 0.12)),
            CovAFixtures.validator(2, stakeInfo: nil, hasSlashes: true, elected: false),
            CovAFixtures.validator(3, stakeInfo: CovAFixtures.stakeInfo(stakeReturn: 0.08))
        ]
    }

    private func flows(_ list: [SelectedValidatorInfo], maxTargets: Int = 2) -> [SelectedValidatorListFlow] {
        [
            .relaychainInitiated(validatorList: list, maxTargets: maxTargets, state: CovAConfirmFixtures.initiated(payout: false)),
            .relaychainExisting(validatorList: list, maxTargets: maxTargets, state: CovAConfirmFixtures.existing(payout: true)),
            .poolInitiated(validatorList: list, poolId: 8, maxTargets: maxTargets, state: CovAConfirmFixtures.initiated(payout: true)),
            .poolExisting(validatorList: list, poolId: 9, maxTargets: maxTargets, state: CovAConfirmFixtures.existing(payout: false))
        ]
    }

    func testStateMapsEveryBaseFlowToConfirmFlowAndRemovesItems() throws {
        let delegate = CovASelectedListDelegateSpy()
        for (index, flow) in flows(validators()).enumerated() {
            let state = SelectedValidatorListRelaychainViewModelState(
                baseFlow: flow, maxTargets: 2, selectedValidatorList: validators(), delegate: delegate
            )
            switch try (index, XCTUnwrap(state.selectValidatorsConfirmFlow())) {
            case let (0, .relaychainInitiated(targets, maxTargets, _)):
                XCTAssertEqual(targets.count, 3)
                XCTAssertEqual(maxTargets, 2)
            case (1, .relaychainExisting):
                break
            case let (2, .poolInitiated(poolId, _, _, _)):
                XCTAssertEqual(poolId, 8)
            case let (3, .poolExisting(poolId, _, _, _)):
                XCTAssertEqual(poolId, 9)
            default:
                XCTFail("unexpected confirm flow at \(index)")
            }
            guard case let .relaychain(info, _) = try XCTUnwrap(state.validatorInfoFlow(validatorIndex: 1)) else {
                return XCTFail("info flow")
            }
            XCTAssertEqual(info?.address, CovAFixtures.address(2))
        }

        let state = SelectedValidatorListRelaychainViewModelState(
            baseFlow: flows(validators())[0], maxTargets: 2, selectedValidatorList: validators(), delegate: delegate
        )
        state.removeItem(at: 0)
        XCTAssertEqual(state.selectedValidatorList.count, 2)
        XCTAssertEqual(delegate.removedAddresses, [CovAFixtures.address(1)])
    }

    func testFactoryMarksExceededLimit() throws {
        let state = SelectedValidatorListRelaychainViewModelState(
            baseFlow: flows(validators())[0], maxTargets: 2, selectedValidatorList: validators(), delegate: nil
        )
        let factory = SelectedValidatorListRelaychainViewModelFactory(
            iconGenerator: UniversalIconGenerator(),
            balanceViewModelFactory: CovAFixtures.balanceFactory()
        )
        let viewModel = try XCTUnwrap(factory.buildViewModel(viewModelState: state, locale: locale))
        XCTAssertTrue(viewModel.limitIsExceeded)
        XCTAssertEqual(viewModel.selectedValidatorsLimit, 2)
        XCTAssertEqual(viewModel.cellViewModels.count, 3)
        XCTAssertEqual(viewModel.cellViewModels[0].name, "One")
        XCTAssertNotNil(viewModel.cellViewModels[0].icon)
        XCTAssertTrue(viewModel.cellViewModels[1].shouldShowError)
        XCTAssertFalse(viewModel.headerViewModel.title.isEmpty)

        state.removeItem(at: 0)
        let reduced = try XCTUnwrap(factory.buildViewModel(viewModelState: state, locale: locale))
        XCTAssertFalse(reduced.limitIsExceeded)
    }

    func testPresenterRoutesSelectionProceedAndDismiss() {
        let delegate = CovASelectedListDelegateSpy()
        let state = SelectedValidatorListRelaychainViewModelState(
            baseFlow: flows(validators(), maxTargets: 16)[1], maxTargets: 16, selectedValidatorList: validators(), delegate: delegate
        )
        let wireframe = CovASelectedListWireframeStub()
        let presenter = SelectedValidatorListPresenter(
            wireframe: wireframe,
            viewModelFactory: SelectedValidatorListRelaychainViewModelFactory(
                iconGenerator: UniversalIconGenerator(),
                balanceViewModelFactory: CovAFixtures.balanceFactory()
            ),
            viewModelState: state,
            localizationManager: CovAFixtures.localizationManager,
            chainAsset: CovAFixtures.chainAsset(),
            wallet: CovAFixtures.wallet()
        )
        let view = CovASelectedListViewStub()
        view.loadViewIfNeeded()
        presenter.view = view

        presenter.setup()
        XCTAssertEqual(view.reloads.last?.cellViewModels.count, 3)
        presenter.didSelectValidator(at: 2)
        presenter.removeItem(at: 2)
        XCTAssertEqual(view.reloads.last?.cellViewModels.count, 2)
        presenter.validatorRemovedAtIndex(0, viewModelState: state)
        XCTAssertEqual(view.removals, [0])
        presenter.proceed()
        presenter.dismiss()
        presenter.applyLocalization()

        XCTAssertEqual(wireframe.infoFlows.count, 1)
        XCTAssertEqual(wireframe.confirmFlows.count, 1)
        XCTAssertEqual(wireframe.dismissals, 1)
        XCTAssertEqual(delegate.removedAddresses, [CovAFixtures.address(3)])
    }

    func testFactoryBuiltModuleRendersEditsAndRemovesRows() throws {
        for (index, flow) in flows(validators(), maxTargets: 16).enumerated() {
            let delegate = CovASelectedListDelegateSpy()
            let view = try XCTUnwrap(SelectedValidatorListViewFactory.createView(
                flow: flow, chainAsset: CovAFixtures.chainAsset(), wallet: CovAFixtures.wallet(), delegate: delegate
            ))
            let controller = try XCTUnwrap(view.controller as? SelectedValidatorListViewController)
            let navigation = UINavigationController(rootViewController: controller)
            let window = CovAViewInspector.host(navigation)
            controller.loadViewIfNeeded()
            let table = controller.rootView.tableView
            table.layoutIfNeeded()

            XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 3, "flow \(index)")
            let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? CustomValidatorCell)
            XCTAssertEqual(cell.titleLabel.text, "One")
            XCTAssertTrue(controller.rootView.proceedButton.isEnabled)

            if index == 0 {
                let editButton = try XCTUnwrap(controller.navigationItem.rightBarButtonItem)
                _ = editButton.target?.perform(editButton.action)
                XCTAssertTrue(table.isEditing)
                controller.tableView(table, commit: .delete, forRowAt: IndexPath(row: 0, section: 0))
                XCTAssertEqual(delegate.removedAddresses, [CovAFixtures.address(1)])
                XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
                _ = editButton.target?.perform(editButton.action)
                XCTAssertFalse(table.isEditing)
                controller.applyLocalization()
                XCTAssertEqual(
                    controller.title,
                    R.string.localizable.stakingSelectedValidatorsTitle(
                        preferredLanguages: controller.localizationManager?.selectedLocale.rLanguages
                    )
                )
            }
            window.isHidden = true
        }
    }

    func testViewControllerDisablesProceedWhenLimitIsExceeded() throws {
        let view = try XCTUnwrap(SelectedValidatorListViewFactory.createView(
            flow: flows(validators(), maxTargets: 2)[0],
            chainAsset: CovAFixtures.chainAsset(),
            wallet: CovAFixtures.wallet(),
            delegate: CovASelectedListDelegateSpy()
        ))
        let controller = try XCTUnwrap(view.controller as? SelectedValidatorListViewController)
        let window = CovAViewInspector.host(UINavigationController(rootViewController: controller))
        XCTAssertFalse(controller.rootView.proceedButton.isEnabled)
        let viewModel = SelectedValidatorListViewModel(
            headerViewModel: TitleWithSubtitleViewModel(title: "Selected"),
            cellViewModels: [],
            limitIsExceeded: false,
            selectedValidatorsLimit: 2
        )
        controller.didReload(viewModel)
        XCTAssertEqual(controller.tableView(controller.rootView.tableView, numberOfRowsInSection: 0), 0)
        window.isHidden = true
    }
}
