import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovARecommendedWireframeStub: RecommendedValidatorListWireframeProtocol {
    private(set) var infoFlows: [ValidatorInfoFlow] = []
    private(set) var confirmFlows: [SelectValidatorsConfirmFlow] = []

    func present(
        flow: ValidatorInfoFlow,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        from _: RecommendedValidatorListViewProtocol?
    ) {
        infoFlows.append(flow)
    }

    func proceed(
        from _: RecommendedValidatorListViewProtocol?,
        flow: SelectValidatorsConfirmFlow,
        wallet _: MetaAccountModel,
        chainAsset _: ChainAsset
    ) {
        confirmFlows.append(flow)
    }
}

final class CovARecommendedListenerSpy: RecommendedValidatorListModelStateListener {
    private(set) var changes = 0
    func modelStateDidChanged(viewModelState _: RecommendedValidatorListViewModelState) {
        changes += 1
    }
}

final class CovARecommendedValidatorListTests: XCTestCase {
    private let locale = CovAFixtures.locale

    private func validators() -> [SelectedValidatorInfo] {
        [
            CovAFixtures.validator(1, identity: CovAFixtures.identity(name: "Rec One"), stakeInfo: CovAFixtures.stakeInfo(stakeReturn: 0.2)),
            CovAFixtures.validator(2, stakeInfo: nil)
        ]
    }

    private func flows(_ list: [SelectedValidatorInfo]) -> [RecommendedValidatorListFlow] {
        [
            .relaychainInitiated(validators: list, maxTargets: 4, bonding: CovAConfirmFixtures.initiated(payout: false)),
            .relaychainExisting(validators: list, maxTargets: 4, bonding: CovAConfirmFixtures.existing(payout: true)),
            .poolInitiated(poolId: 6, validators: list, maxTargets: 4, bonding: CovAConfirmFixtures.initiated(payout: true)),
            .poolExisting(poolId: 7, validators: list, maxTargets: 4, bonding: CovAConfirmFixtures.existing(payout: false))
        ]
    }

    func testContainersBuildStatesFactoriesAndConfirmFlows() throws {
        for (index, flow) in flows(validators()).enumerated() {
            let container = try XCTUnwrap(RecommendedValidatorListViewFactory.createContainer(
                flow: flow, chainAsset: CovAFixtures.chainAsset(), wallet: CovAFixtures.wallet()
            ))
            let listener = CovARecommendedListenerSpy()
            container.viewModelState.setStateListener(listener)
            container.strategy.setup()
            XCTAssertFalse(container.viewModelState.shouldSelectValidatorAt(index: 0))

            let viewModel = try XCTUnwrap(container.viewModelFactory.buildViewModel(
                viewModelState: container.viewModelState, locale: locale
            ))
            XCTAssertEqual(viewModel.itemViewModels.count, 2)
            XCTAssertTrue(viewModel.continueButtonEnabled)
            XCTAssertFalse(viewModel.title.isEmpty)
            XCTAssertFalse(viewModel.continueButtonTitle.isEmpty)
            XCTAssertTrue(viewModel.itemsCountString.value(for: locale).contains("4"))
            let first = viewModel.itemViewModels[0].value(for: locale)
            XCTAssertEqual(first.title, "Rec One")
            XCTAssertTrue(try XCTUnwrap(first.detailsAttributedString?.string).hasPrefix("APY"))
            XCTAssertTrue(first.isSelected)
            XCTAssertEqual(viewModel.itemViewModels[1].value(for: locale).title, CovAFixtures.address(2))

            switch try (index, XCTUnwrap(container.viewModelState.selectValidatorsConfirmFlow())) {
            case (0, .relaychainInitiated), (1, .relaychainExisting):
                break
            case let (2, .poolInitiated(poolId, targets, _, _)):
                XCTAssertEqual(poolId, 6)
                XCTAssertEqual(targets.count, 2)
            case let (3, .poolExisting(poolId, _, _, _)):
                XCTAssertEqual(poolId, 7)
            default:
                XCTFail("unexpected confirm flow at \(index)")
            }

            switch try (index, XCTUnwrap(container.viewModelState.validatorInfoFlow(validatorIndex: 0))) {
            case (0, .relaychain), (1, .relaychain), (2, .pool), (3, .pool):
                break
            default:
                XCTFail("unexpected info flow at \(index)")
            }
        }
    }

    func testEmptyValidatorListsHaveNoConfirmFlow() throws {
        for (index, flow) in flows([]).enumerated() where index != 2 {
            let container = try XCTUnwrap(RecommendedValidatorListViewFactory.createContainer(
                flow: flow, chainAsset: CovAFixtures.chainAsset(), wallet: CovAFixtures.wallet()
            ))
            XCTAssertNil(container.viewModelState.selectValidatorsConfirmFlow(), "flow \(index)")
        }
    }

    func testFactoriesRejectForeignStates() throws {
        let relay = try XCTUnwrap(RecommendedValidatorListViewFactory.createContainer(
            flow: flows(validators())[0], chainAsset: CovAFixtures.chainAsset(), wallet: CovAFixtures.wallet()
        ))
        let pool = try XCTUnwrap(RecommendedValidatorListViewFactory.createContainer(
            flow: flows(validators())[2], chainAsset: CovAFixtures.chainAsset(), wallet: CovAFixtures.wallet()
        ))
        XCTAssertNil(relay.viewModelFactory.buildViewModel(viewModelState: pool.viewModelState, locale: locale))
        XCTAssertNil(pool.viewModelFactory.buildViewModel(viewModelState: relay.viewModelState, locale: locale))
    }

    func testFactoryBuiltModuleRendersAndRoutes() throws {
        let view = try XCTUnwrap(RecommendedValidatorListViewFactory.createView(
            flow: flows(validators())[1], chainAsset: CovAFixtures.chainAsset(), wallet: CovAFixtures.wallet()
        ))
        let controller = try XCTUnwrap(view.controller as? RecommendedValidatorListViewController)
        let presenter = try XCTUnwrap(controller.presenter as? RecommendedValidatorListPresenter)
        let wireframe = CovARecommendedWireframeStub()
        presenter.wireframe = wireframe
        let window = CovAViewInspector.host(UINavigationController(rootViewController: controller))
        controller.loadViewIfNeeded()
        let table = try XCTUnwrap(CovAViewInspector.subviews(of: UITableView.self, in: controller.view).first)
        table.layoutIfNeeded()

        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? CustomValidatorCell)
        XCTAssertEqual(cell.titleLabel.text, "Rec One")
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        presenter.showValidatorInfoAt(index: 1)
        XCTAssertEqual(wireframe.infoFlows.count, 1)
        controller.continueButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(wireframe.confirmFlows.count, 1)
        if let visible = table.visibleCells.first as? CustomValidatorCell {
            controller.didTapInfoButton(in: visible)
            XCTAssertEqual(wireframe.infoFlows.count, 2)
        }
        controller.applyLocalization()
        XCTAssertFalse((controller.title ?? "").isEmpty)
        window.isHidden = true
    }
}
