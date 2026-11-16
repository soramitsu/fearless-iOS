import XCTest
import UIKit
import SoraFoundation
import SSFModels
@testable import fearless

final class CovJNodeActions: NodeSelectionPresenterProtocol, NodeSelectionTableCellViewModelDelegate {
    var setupCount = 0
    var selected: [ChainNodeModel] = []
    var switches: [Bool] = []
    var closeCount = 0
    var addCount = 0
    var deleted: [ChainNodeModel] = []
    var defaultInfo: [ChainNodeModel] = []
    var customInfo: [ChainNodeModel] = []

    func setup() { setupCount += 1 }
    func didSelectNode(_ node: ChainNodeModel) { selected.append(node) }
    func didChangeValueForAutomaticNodeSwitch(isOn: Bool) { switches.append(isOn) }
    func didTapCloseButton() { closeCount += 1 }
    func didTapAddNodeButton() { addCount += 1 }
    func deleteNode(_ node: ChainNodeModel) { deleted.append(node) }
    func showDefaultNodeInfo(_ node: ChainNodeModel) { defaultInfo.append(node) }
    func showCustomNodeInfo(_ node: ChainNodeModel) { customInfo.append(node) }
}

final class CovJNodeSelectionTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")

    private func node(_ name: String, scheme: String = "wss") throws -> ChainNodeModel {
        ChainNodeModel(url: try XCTUnwrap(URL(string: "\(scheme)://\(name.lowercased()).invalid")), name: name, apikey: nil)
    }

    private func chain(nodes: Set<ChainNodeModel>, custom: Set<ChainNodeModel>? = nil, selected: ChainNodeModel? = nil) -> ChainModel {
        ChainModel(rank: nil, disabled: false, chainId: "test-chain", parentId: nil, paraId: nil, name: "Test chain",
                   xcm: nil, nodes: nodes, addressPrefix: 42, types: nil, icon: nil, options: nil, externalApi: nil,
                   selectedNode: selected, customNodes: custom, iosMinAppVersion: nil, identityChain: nil)
    }

    func testFactorySortsDefaultNodesExcludesHTTPAndMarksSelection() throws {
        let alpha = try node("Alpha")
        let beta = try node("Beta")
        let custom = try node("Custom")
        let http = try node("Http", scheme: "https")
        let actions = CovJNodeActions()
        let model = NodeSelectionViewModelFactory().buildViewModel(
            from: chain(nodes: [beta, alpha, http], custom: [custom, http], selected: alpha),
            locale: locale, cellsDelegate: actions
        )
        XCTAssertEqual(model.title, "Test chain")
        XCTAssertFalse(model.autoSelectEnabled)
        XCTAssertEqual(model.sections.count, 2)
        XCTAssertEqual(model.sections[0].viewModels.map(\.node), [custom])
        XCTAssertEqual(model.sections[1].viewModels.map(\.node), [alpha, beta])
        XCTAssertTrue(model.sections[0].viewModels[0].editable)
        XCTAssertFalse(model.sections[1].viewModels[0].editable)
        XCTAssertTrue(model.sections[1].viewModels[0].selected)
        XCTAssertFalse(model.sections[1].viewModels[1].selected)
        XCTAssertTrue(model.sections.flatMap(\.viewModels).allSatisfy(\.selectable))
        model.sections[0].viewModels[0].didTapInfoButton()
        model.sections[1].viewModels[0].didTapInfoButton()
        model.sections[0].viewModels[0].didTapDeleteButton()
        XCTAssertEqual(actions.customInfo, [custom])
        XCTAssertEqual(actions.defaultInfo, [alpha])
        XCTAssertEqual(actions.deleted, [custom])
    }

    func testFactoryHandlesAutomaticEmptyAndDeleteConfirmation() throws {
        let alpha = try node("Alpha")
        let factory = NodeSelectionViewModelFactory()
        let automatic = factory.buildViewModel(from: chain(nodes: [alpha]), locale: locale, cellsDelegate: nil)
        XCTAssertTrue(automatic.autoSelectEnabled)
        XCTAssertEqual(automatic.sections.count, 1)
        XCTAssertFalse(automatic.sections[0].viewModels[0].selectable)
        XCTAssertFalse(automatic.sections[0].viewModels[0].selected)
        let empty = factory.buildViewModel(from: chain(nodes: []), locale: locale, cellsDelegate: nil)
        XCTAssertTrue(empty.sections.isEmpty)
        var deleted = 0
        let alert = factory.buildDeleteNodeAlertViewModel(node: alpha, locale: locale) { deleted += 1 }
        XCTAssertEqual(alert.message, "Alpha")
        XCTAssertEqual(alert.actions.count, 1)
        XCTAssertEqual(alert.closeAction, R.string.localizable.commonClose(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(deleted, 0)
        alert.actions[0].handler?()
        XCTAssertEqual(deleted, 1)
    }

    func testNodeCellDeletionVisibilityAndDelegateRouting() throws {
        let node = try node("Custom")
        let actions = CovJNodeActions()
        let model = NodeSelectionTableCellViewModel(node: node, selected: false, selectable: true, editable: true, delegate: actions)
        let cell = NodeSelectionTableCell(style: .default, reuseIdentifier: nil)
        cell.bind(to: model, tableState: .normal)
        XCTAssertEqual(cell.nodeNameLabel.text, "Custom")
        XCTAssertEqual(cell.nodeUrlLabel.text, node.clearUrlString)
        XCTAssertTrue(cell.selectedIconImageView.isHidden)
        XCTAssertEqual(cell.deleteButton.alpha, 0)
        cell.bind(to: model, tableState: .editing)
        XCTAssertEqual(cell.deleteButton.alpha, 1)
        cell.infoButton.sendActions(for: .touchUpInside)
        cell.deleteButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.customInfo, [node])
        XCTAssertEqual(actions.deleted, [node])
        cell.prepareForReuse()
        cell.bind(to: NodeSelectionTableCellViewModel(node: node, selected: true, selectable: false, editable: false, delegate: actions), tableState: .editing)
        XCTAssertFalse(cell.selectedIconImageView.isHidden)
        XCTAssertTrue(cell.deleteButton.isHidden)
        XCTAssertEqual(cell.nodeNameLabel.textColor, R.color.colorGray())
        cell.infoButton.sendActions(for: .touchUpInside)
    }

    func testControllerLoadingAndLoadedSectionsRouteAllControls() throws {
        let actions = CovJNodeActions()
        let controller = NodeSelectionViewController(presenter: actions)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let table = controller.rootView.tableView
        controller.didReceive(locale: locale)
        XCTAssertEqual(actions.setupCount, 1)
        XCTAssertEqual(controller.numberOfSections(in: table), 0)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)
        XCTAssertNil(controller.tableView(table, viewForHeaderInSection: 0))
        XCTAssertEqual(controller.tableView(table, heightForHeaderInSection: 0), 0)
        let node = try node("Alpha")
        let cellModel = NodeSelectionTableCellViewModel(node: node, selected: false, selectable: true, editable: true, delegate: actions)
        let model = NodeSelectionViewModel(title: "Test nodes", autoSelectEnabled: true, sections: [
            NodeSelectionTableSection(title: "Custom", viewModels: [cellModel]),
            NodeSelectionTableSection(title: "Default", viewModels: [])
        ])
        controller.didReceive(state: .loaded(viewModel: model))
        XCTAssertEqual(controller.numberOfSections(in: table), 2)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 1)
        XCTAssertFalse(controller.rootView.editButton.isHidden)
        XCTAssertEqual(controller.rootView.navigationTitleLabel.text, "Test nodes")
        XCTAssertTrue(controller.rootView.switchView.isOn)
        XCTAssertEqual(controller.rootView.switchTitle.textColor, R.color.colorWhite())
        let header = try XCTUnwrap(controller.tableView(table, viewForHeaderInSection: 0) as? TableSectionTitleView)
        XCTAssertEqual(header.titleLabel.text, "Custom")
        XCTAssertEqual(controller.tableView(table, heightForHeaderInSection: 0), 30)
        XCTAssertEqual(controller.tableView(table, heightForHeaderInSection: 1), .leastNormalMagnitude)
        XCTAssertEqual(controller.tableView(table, heightForFooterInSection: 0), .leastNormalMagnitude)
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? NodeSelectionTableCell)
        XCTAssertEqual(cell.nodeNameLabel.text, "Alpha")
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(actions.selected, [node])
        controller.rootView.switchView.isOn = false
        controller.rootView.switchView.sendActions(for: .valueChanged)
        XCTAssertEqual(actions.switches, [false])
        controller.rootView.editButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(controller.tableState, .editing)
        XCTAssertEqual(controller.rootView.editButton.title(for: .normal), R.string.localizable.commonDone(preferredLanguages: locale.rLanguages))
        controller.rootView.editButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(controller.tableState, .normal)
        controller.rootView.addNodeButton.sendActions(for: .touchUpInside)
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.addCount, 1)
        XCTAssertEqual(actions.closeCount, 1)
        controller.tableState = .editing
        controller.viewWillDisappear(false)
        XCTAssertEqual(controller.tableState, .normal)
        controller.didReceive(state: .loaded(viewModel: NodeSelectionViewModel(title: "Manual", autoSelectEnabled: false, sections: [])))
        XCTAssertTrue(controller.rootView.editButton.isHidden)
        XCTAssertFalse(controller.rootView.switchView.isOn)
        XCTAssertEqual(controller.rootView.switchTitle.textColor, R.color.colorGray())
    }
}
