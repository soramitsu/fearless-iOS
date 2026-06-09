import XCTest
import SSFModels
@testable import fearless

final class NetworkManagementTests: XCTestCase {
    func testFilter_whenInitializedFromIdentifiers_thenExposesExpectedState() {
        let allFromNil = NetworkManagmentFilter(identifier: nil)
        XCTAssertEqual(allFromNil.identifier, "all")
        XCTAssertNil(allFromNil.selectedChainId)
        XCTAssertTrue(allFromNil.isAllFilter)
        XCTAssertFalse(allFromNil.isChainSelected)
        XCTAssertFalse(allFromNil.isPopularFilter)
        XCTAssertFalse(allFromNil.isFavouriteFilter)
        XCTAssertNotNil(allFromNil.filterImage)

        let all = NetworkManagmentFilter(identifier: "all")
        XCTAssertEqual(all.identifier, "all")
        XCTAssertTrue(all.isAllFilter)
        XCTAssertNotNil(all.filterImage)

        let popular = NetworkManagmentFilter(identifier: "popular")
        XCTAssertEqual(popular.identifier, "popular")
        XCTAssertTrue(popular.isPopularFilter)
        XCTAssertFalse(popular.isAllFilter)
        XCTAssertFalse(popular.isFavouriteFilter)
        XCTAssertFalse(popular.isChainSelected)
        XCTAssertNil(popular.selectedChainId)
        XCTAssertNotNil(popular.filterImage)

        let favourite = NetworkManagmentFilter(identifier: "favourite")
        XCTAssertEqual(favourite.identifier, "favourite")
        XCTAssertTrue(favourite.isFavouriteFilter)
        XCTAssertFalse(favourite.isAllFilter)
        XCTAssertFalse(favourite.isPopularFilter)
        XCTAssertFalse(favourite.isChainSelected)
        XCTAssertNil(favourite.selectedChainId)
        XCTAssertNotNil(favourite.filterImage)

        let chain = NetworkManagmentFilter(identifier: "sora-mainnet")
        XCTAssertEqual(chain.identifier, "sora-mainnet")
        XCTAssertEqual(chain.selectedChainId, "sora-mainnet")
        XCTAssertTrue(chain.isChainSelected)
        XCTAssertFalse(chain.isAllFilter)
        XCTAssertFalse(chain.isPopularFilter)
        XCTAssertFalse(chain.isFavouriteFilter)
        XCTAssertNil(chain.filterImage)
    }

    func testBuildViewModel_whenChainHasDefaultAndCustomNodes_thenGroupsNodesAndMarksSelection() {
        let selectedNode = makeNode(name: "Alpha", url: "wss://alpha.example")
        let defaultNode = makeNode(name: "Beta", url: "wss://beta.example")
        let httpNode = makeNode(name: "HTTP", url: "https://http.example")
        let customNode = makeNode(name: "Custom", url: "wss://custom.example")
        let delegate = NodeSelectionTableCellDelegateSpy()
        let factory = NodeSelectionViewModelFactory()
        let chain = makeChain(
            nodes: [defaultNode, selectedNode, httpNode],
            selectedNode: selectedNode,
            customNodes: [customNode]
        )

        let viewModel = factory.buildViewModel(
            from: chain,
            locale: Locale(identifier: "en"),
            cellsDelegate: delegate
        )

        XCTAssertEqual(viewModel.title, "Network")
        XCTAssertEqual(viewModel.autoSelectEnabled, false)
        XCTAssertEqual(viewModel.sections.count, 2)

        let customSection = viewModel.sections[0]
        XCTAssertEqual(customSection.viewModels.map(\.node), [customNode])
        XCTAssertEqual(customSection.viewModels.map(\.editable), [true])
        XCTAssertEqual(customSection.viewModels.map(\.selectable), [true])
        XCTAssertEqual(customSection.viewModels.map(\.selected), [false])
        XCTAssertTrue(customSection.viewModels.first?.delegate === delegate)

        let defaultSection = viewModel.sections[1]
        XCTAssertEqual(defaultSection.viewModels.map(\.node), [selectedNode, defaultNode])
        XCTAssertEqual(defaultSection.viewModels.map(\.editable), [false, false])
        XCTAssertEqual(defaultSection.viewModels.map(\.selectable), [true, true])
        XCTAssertEqual(defaultSection.viewModels.map(\.selected), [true, false])
        XCTAssertFalse(defaultSection.viewModels.contains { $0.node == httpNode })
        XCTAssertTrue(defaultSection.viewModels.allSatisfy { $0.delegate === delegate })
    }

    func testBuildViewModel_whenAutomaticSwitchIsEnabled_thenCellsAreNotSelectable() {
        let defaultNode = makeNode(name: "Default", url: "wss://default.example")
        let customNode = makeNode(name: "Custom", url: "wss://custom.example")
        let factory = NodeSelectionViewModelFactory()
        let chain = makeChain(
            nodes: [defaultNode],
            selectedNode: nil,
            customNodes: [customNode]
        )

        let viewModel = factory.buildViewModel(
            from: chain,
            locale: Locale(identifier: "en"),
            cellsDelegate: nil
        )
        let cells = viewModel.sections.flatMap(\.viewModels)

        XCTAssertEqual(viewModel.autoSelectEnabled, true)
        XCTAssertEqual(cells.map(\.selectable), [false, false])
        XCTAssertEqual(cells.map(\.selected), [false, false])
    }

    func testDeleteNodeAlertViewModel_whenActionRuns_thenInvokesDeleteHandler() {
        let factory = NodeSelectionViewModelFactory()
        let node = makeNode(name: "Custom", url: "wss://custom.example")
        var didDelete = false

        let viewModel = factory.buildDeleteNodeAlertViewModel(
            node: node,
            locale: Locale(identifier: "en")
        ) {
            didDelete = true
        }
        viewModel.actions.first?.handler?()

        XCTAssertEqual(viewModel.message, "Custom")
        XCTAssertEqual(viewModel.actions.count, 1)
        XCTAssertTrue(didDelete)
    }

    private func makeNode(name: String, url: String) -> ChainNodeModel {
        ChainNodeModel(url: URL(string: url)!, name: name, apikey: nil)
    }

    private func makeChain(
        nodes: Set<ChainNodeModel>,
        selectedNode: ChainNodeModel?,
        customNodes: Set<ChainNodeModel>?
    ) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: UUID().uuidString,
            parentId: nil,
            paraId: nil,
            name: "Network",
            xcm: nil,
            nodes: nodes,
            addressPrefix: 0,
            types: nil,
            icon: URL(string: "https://example.com/icon.png"),
            options: nil,
            externalApi: nil,
            selectedNode: selectedNode,
            customNodes: customNodes,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

private final class NodeSelectionTableCellDelegateSpy: NodeSelectionTableCellViewModelDelegate {
    private(set) var deletedNode: ChainNodeModel?
    private(set) var defaultInfoNode: ChainNodeModel?
    private(set) var customInfoNode: ChainNodeModel?

    func deleteNode(_ node: ChainNodeModel) {
        deletedNode = node
    }

    func showDefaultNodeInfo(_ node: ChainNodeModel) {
        defaultInfoNode = node
    }

    func showCustomNodeInfo(_ node: ChainNodeModel) {
        customInfoNode = node
    }
}
