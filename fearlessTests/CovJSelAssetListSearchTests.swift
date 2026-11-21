import XCTest
import UIKit
import SoraFoundation
import SSFModels
@testable import fearless

final class CovJSelAssetListInputSpy: ChainAssetListModuleInput {
    private(set) var updates: [[ChainAssetsFetching.Filter]] = []
    private(set) var networkFilters: [NetworkManagmentFilter?] = []

    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts _: [ChainAssetsFetching.SortDescriptor],
        networkFilter: NetworkManagmentFilter?
    ) {
        updates.append(filters)
        networkFilters.append(networkFilter)
    }
}

final class CovJSelAssetListSearchViewSpy: UIViewController, AssetListSearchViewInput {}

final class CovJSelAssetListSearchInteractorSpy: AssetListSearchInteractorInput {
    private(set) var outputs: [AssetListSearchInteractorOutput] = []

    func setup(with output: AssetListSearchInteractorOutput) {
        outputs.append(output)
    }
}

final class CovJSelAssetListSearchOutputSpy: AssetListSearchViewOutput {
    private(set) var loaded = 0
    private(set) var cancels = 0
    private(set) var searches: [String?] = []

    func didLoad(view _: AssetListSearchViewInput) { loaded += 1 }
    func didTapOnCalcel() { cancels += 1 }
    func searchTextDidChange(_ text: String?) { searches.append(text) }
}

final class CovJSelAssetListSearchTests: XCTestCase {
    func testPresenterLoadsFullListSearchesAndDismisses() throws {
        let list = CovJSelAssetListInputSpy()
        let interactor = CovJSelAssetListSearchInteractorSpy()
        let router = CovJSelDismissSpy()
        let view = CovJSelAssetListSearchViewSpy()
        let presenter = AssetListSearchPresenter(
            assetListModuleInput: list,
            interactor: interactor,
            router: router,
            localizationManager: try CovJSelFixture.manager()
        )

        presenter.didLoad(view: view)
        XCTAssertTrue(interactor.outputs.first === presenter)
        XCTAssertEqual(list.updates, [[]])
        XCTAssertEqual(list.networkFilters.count, 1)
        XCTAssertNil(list.networkFilters.first ?? nil)

        presenter.searchTextDidChange("dot")
        presenter.searchTextDidChange("")
        presenter.searchTextDidChange(nil)
        XCTAssertEqual(list.updates, [[], [.search("dot")], []], "a nil text is ignored")

        presenter.didTapOnCalcel()
        XCTAssertEqual(router.dismissed.count, 1)
        XCTAssertTrue(router.dismissed.first ?? nil === view)
        presenter.applyLocalization()
    }

    func testInteractorKeepsItsOutput() {
        let interactor = AssetListSearchInteractor()
        let list = CovJSelAssetListInputSpy()
        let presenter = AssetListSearchPresenter(assetListModuleInput: list, interactor: interactor, router: AssetListSearchRouter(),
                                                 localizationManager: LocalizationManager.shared)
        presenter.didLoad(view: CovJSelAssetListSearchViewSpy())
        presenter.didTapOnCalcel()
        XCTAssertEqual(list.updates.count, 1)
    }

    func testControllerEmbedsListLocalizesAndForwardsSearchAndCancel() throws {
        let manager = try CovJSelFixture.manager()
        let output = CovJSelAssetListSearchOutputSpy()
        let child = UIViewController()
        let controller = AssetListSearchViewController(assetListViewController: child, output: output, localizationManager: manager)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }

        XCTAssertEqual(output.loaded, 1)
        XCTAssertTrue(controller.children.contains(child))
        XCTAssertTrue(child.view.superview === controller.rootView.assetListViewContainer)
        XCTAssertEqual(child.view.frame.size, controller.rootView.assetListViewContainer.bounds.size)
        let languages = manager.selectedLocale.rLanguages
        XCTAssertEqual(controller.rootView.cancelButton.title(for: .normal), R.string.localizable.commonCancel(preferredLanguages: languages))
        XCTAssertEqual(controller.rootView.searchTextField.textField.placeholder,
                       R.string.localizable.manageAssetsSearchHint(preferredLanguages: languages))
        XCTAssertNotNil(controller.rootView.backgroundImageView.image)

        controller.rootView.searchTextField.onTextDidChanged?("ksm")
        XCTAssertEqual(output.searches, ["ksm"])
        controller.rootView.cancelButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.cancels, 1)
        controller.applyLocalization()
        XCTAssertEqual(controller.rootView.locale, manager.selectedLocale)
    }
}
