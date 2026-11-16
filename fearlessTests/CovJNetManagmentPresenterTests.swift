import XCTest
import UIKit
import SoraFoundation
import SSFModels
@testable import fearless

final class CovJNetManagmentViewSpy: UIViewController, NetworkManagmentViewInput {
    var viewModels: [NetworkManagmentViewModel] = []
    func didReceive(viewModel: NetworkManagmentViewModel) { viewModels.append(viewModel) }
}

final class CovJNetManagmentInteractorSpy: NetworkManagmentInteractorInput {
    weak var output: NetworkManagmentInteractorOutput?
    var setups = 0
    var favourites: [String] = []
    var selections: [String] = []

    func setup(with output: NetworkManagmentInteractorOutput) {
        setups += 1
        self.output = output
    }

    func didTapFavoutite(with identifier: String) { favourites.append(identifier) }
    func didSelect(_ identifier: String) { selections.append(identifier) }
}

final class CovJNetManagmentRouterSpy: NetworkManagmentRouterInput {
    var dismissed: [UIViewController?] = []
    func dismiss(view: ControllerBackedProtocol?) { dismissed.append(view?.controller) }
}

final class CovJNetManagmentModuleOutputSpy: NetworkManagmentModuleOutput {
    var selections: [(String, Int?)] = []
    func did(select: NetworkManagmentFilter, contextTag: Int?) { selections.append((select.identifier, contextTag)) }
}

final class CovJNetManagmentPresenterTests: XCTestCase {
    private struct Fixture {
        let presenter: NetworkManagmentPresenter
        let view: CovJNetManagmentViewSpy
        let interactor: CovJNetManagmentInteractorSpy
        let router: CovJNetManagmentRouterSpy
        let output: CovJNetManagmentModuleOutputSpy
    }

    private let alpha = CovJNetFixture.chain(name: "Alpha", rank: 2, icon: URL(string: "https://example.invalid/alpha.svg"))
    private let beta = CovJNetFixture.chain(name: "Beta", rank: 1)
    private let gamma = CovJNetFixture.chain(name: "Gamma")

    private var languages: [String]? { CovJNetFixture.locale.rLanguages }
    private var allTitle: String { R.string.localizable.chainSelectionAllNetworks(preferredLanguages: languages) }
    private var popularTitle: String { R.string.localizable.networkManagementPopular(preferredLanguages: languages).uppercased() }
    private var favouriteTitle: String { R.string.localizable.networkManagmentFavourite(preferredLanguages: languages).uppercased() }

    private func makeFixture(wallet: MetaAccountModel = AccountGenerator.generateMetaAccount(), tag: Int? = 7) -> Fixture {
        let view = CovJNetManagmentViewSpy()
        let interactor = CovJNetManagmentInteractorSpy()
        let router = CovJNetManagmentRouterSpy()
        let output = CovJNetManagmentModuleOutputSpy()
        let presenter = NetworkManagmentPresenter(
            wallet: wallet,
            interactor: interactor,
            router: router,
            moduleOutput: output,
            logger: Logger.shared,
            viewModelFactory: NetworkManagmentViewModelFactoryImpl(),
            contextTag: tag,
            localizationManager: LocalizationManager.shared
        )
        presenter.didLoad(view: view)
        return Fixture(presenter: presenter, view: view, interactor: interactor, router: router, output: output)
    }

    func testLoadStartsInteractorAndRendersAllNetworksSortedByName() throws {
        let fixture = makeFixture()
        XCTAssertEqual(fixture.interactor.setups, 1)
        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
        XCTAssertTrue(fixture.view.viewModels.isEmpty)

        fixture.presenter.didReceiveChains(result: .success([gamma, beta, alpha]))

        let model = try XCTUnwrap(fixture.view.viewModels.last)
        XCTAssertEqual(model.activeFilter.identifier, "all")
        XCTAssertEqual(model.cells.map(\.name), [allTitle, "Alpha", "Beta", "Gamma"])
        XCTAssertEqual(model.cells.map(\.isSelected), [true, false, false, false])
        XCTAssertEqual(model.cells.map(\.isFavourite), [nil, false, false, false])
        XCTAssertEqual(model.cells.map(\.networkSelectType.identifier), ["all", alpha.chainId, beta.chainId, gamma.chainId])
        XCTAssertTrue(model.cells[0].icon is BundleImageViewModel)
        XCTAssertTrue(model.cells[1].icon is RemoteImageViewModel)
        XCTAssertNil(model.cells[2].icon)

        fixture.presenter.didReceiveChains(result: .failure(CovJError("offline")))
        XCTAssertEqual(fixture.view.viewModels.count, 1)
    }

    func testSearchAndFilterButtonsRebuildTheList() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let fixture = makeFixture(wallet: wallet)
        fixture.presenter.didReceiveChains(result: .success([alpha, beta, gamma]))

        fixture.presenter.searchTextDidChanged("ALP")
        XCTAssertEqual(fixture.view.viewModels.last?.cells.map(\.name), [allTitle, "Alpha"])

        fixture.presenter.searchTextDidChanged("zzz")
        XCTAssertEqual(fixture.view.viewModels.last?.cells.count, 0)

        fixture.presenter.searchTextDidChanged(nil)
        fixture.presenter.didSelectPopularFilter()
        let popular = try XCTUnwrap(fixture.view.viewModels.last)
        XCTAssertTrue(popular.activeFilter.isPopularFilter)
        XCTAssertEqual(popular.cells.map(\.name), [popularTitle, "Beta", "Alpha"])
        XCTAssertEqual(popular.cells.map(\.isSelected), [false, false, false])
        XCTAssertEqual(popular.cells.first?.networkSelectType.identifier, "popular")

        fixture.presenter.didSelectFavouriteFilter()
        let noFavourites = try XCTUnwrap(fixture.view.viewModels.last)
        XCTAssertTrue(noFavourites.activeFilter.isFavouriteFilter)
        XCTAssertTrue(noFavourites.cells.isEmpty)

        fixture.presenter.didReceiveUpdated(wallet: wallet.replacingFavoutites([gamma.chainId]))
        let favourites = try XCTUnwrap(fixture.view.viewModels.last)
        XCTAssertEqual(favourites.cells.map(\.name), [favouriteTitle, "Gamma"])
        XCTAssertEqual(favourites.cells.map(\.isFavourite), [nil, true])
        XCTAssertEqual(favourites.cells.first?.networkSelectType.identifier, "favourite")

        fixture.presenter.didSelectAllFilter()
        let all = try XCTUnwrap(fixture.view.viewModels.last)
        XCTAssertTrue(all.activeFilter.isAllFilter)
        XCTAssertEqual(all.cells.count, 4)
        XCTAssertEqual(all.cells.last?.isFavourite, true)

        let count = fixture.view.viewModels.count
        fixture.presenter.applyLocalization()
        XCTAssertEqual(fixture.view.viewModels.count, count)
    }

    func testFavouriteTapsAndRowSelectionUseTheShownRows() throws {
        let fixture = makeFixture(tag: 7)
        fixture.presenter.didTappedFavouriteButton(at: IndexPath(row: 1, section: 0))
        fixture.presenter.didSelectRow(at: IndexPath(row: 1, section: 0))
        XCTAssertTrue(fixture.interactor.favourites.isEmpty)
        XCTAssertTrue(fixture.interactor.selections.isEmpty)
        XCTAssertTrue(fixture.router.dismissed.isEmpty)

        fixture.presenter.didReceiveChains(result: .success([alpha, beta]))
        fixture.presenter.didTappedFavouriteButton(at: nil)
        fixture.presenter.didTappedFavouriteButton(at: IndexPath(row: 9, section: 0))
        XCTAssertTrue(fixture.interactor.favourites.isEmpty)
        fixture.presenter.didTappedFavouriteButton(at: IndexPath(row: 1, section: 0))
        fixture.presenter.didTappedFavouriteButton(at: IndexPath(row: 0, section: 0))
        XCTAssertEqual(fixture.interactor.favourites, [alpha.chainId, "all"])

        fixture.presenter.didSelectRow(at: IndexPath(row: 5, section: 0))
        XCTAssertTrue(fixture.output.selections.isEmpty)

        fixture.presenter.didSelectRow(at: IndexPath(row: 2, section: 0))
        XCTAssertEqual(fixture.output.selections.map(\.0), [beta.chainId])
        XCTAssertEqual(fixture.output.selections.map(\.1), [7])
        XCTAssertEqual(fixture.interactor.selections, [beta.chainId])
        XCTAssertEqual(fixture.router.dismissed.count, 1)
        XCTAssertTrue(fixture.router.dismissed.first ?? nil === fixture.view)

        fixture.presenter.didTapBackButton()
        XCTAssertEqual(fixture.router.dismissed.count, 2)
    }

    func testWalletFilterMarksTheStoredChainAndKeepsChainFilterActive() throws {
        let wallet = AccountGenerator.generateMetaAccount().replacingNetworkManagmentFilter(beta.chainId)
        let fixture = makeFixture(wallet: wallet, tag: nil)
        fixture.presenter.didReceiveChains(result: .success([alpha, beta]))

        let model = try XCTUnwrap(fixture.view.viewModels.last)
        XCTAssertTrue(model.activeFilter.isChainSelected)
        XCTAssertEqual(model.activeFilter.selectedChainId, beta.chainId)
        XCTAssertEqual(model.cells.map(\.isSelected), [false, false, true])

        fixture.presenter.didSelectRow(at: IndexPath(row: 0, section: 0))
        XCTAssertEqual(fixture.output.selections.map(\.0), ["all"])
        XCTAssertEqual(fixture.output.selections.first?.1, nil)
    }

    func testFactoryMarksStoredPopularAndFavouriteFilters() {
        let factory = NetworkManagmentViewModelFactoryImpl()
        let wallet = AccountGenerator.generateMetaAccount().replacingFavoutites([alpha.chainId, beta.chainId])
        let locale = CovJNetFixture.locale

        let favourite = factory.createViewModel(
            wallet: wallet, chains: [gamma, beta, alpha], selectedFilter: nil,
            initialFilter: .favourite, searchText: "", locale: locale
        )
        XCTAssertTrue(favourite.activeFilter.isFavouriteFilter)
        XCTAssertEqual(favourite.cells.map(\.name), [favouriteTitle, "Alpha", "Beta"])
        XCTAssertEqual(favourite.cells.map(\.isSelected), [true, false, false])

        let popular = factory.createViewModel(
            wallet: wallet, chains: [gamma, beta, alpha], selectedFilter: nil,
            initialFilter: .popular, searchText: nil, locale: locale
        )
        XCTAssertEqual(popular.cells.map(\.name), [popularTitle, "Beta", "Alpha"])
        XCTAssertEqual(popular.cells.map(\.isSelected), [true, false, false])
        XCTAssertEqual(popular.cells.map(\.isFavourite), [nil, true, true])

        let empty = factory.createViewModel(
            wallet: wallet, chains: [], selectedFilter: .all,
            initialFilter: .popular, searchText: nil, locale: locale
        )
        XCTAssertTrue(empty.cells.isEmpty)
        XCTAssertTrue(empty.activeFilter.isAllFilter)
    }

    func testFilterIdentifiersAndFlags() {
        XCTAssertEqual(NetworkManagmentFilter(identifier: nil).identifier, "all")
        for identifier in ["all", "popular", "favourite", "covjnet-chain"] {
            XCTAssertEqual(NetworkManagmentFilter(identifier: identifier).identifier, identifier)
        }

        let filters: [NetworkManagmentFilter] = [.all, .popular, .favourite, .chain("covjnet-chain")]
        XCTAssertEqual(filters.map(\.isAllFilter), [true, false, false, false])
        XCTAssertEqual(filters.map(\.isPopularFilter), [false, true, false, false])
        XCTAssertEqual(filters.map(\.isFavouriteFilter), [false, false, true, false])
        XCTAssertEqual(filters.map(\.isChainSelected), [false, false, false, true])
        XCTAssertEqual(filters.map(\.selectedChainId), [nil, nil, nil, "covjnet-chain"])
        XCTAssertEqual(filters.map { $0.filterImage != nil }, [true, true, true, false])
    }

    func testItemsExposeOnlyTheirChain() {
        let items: [NetworkManagmentItem] = [.allItem, .popular, .favourite, .chain(alpha)]
        XCTAssertEqual(items.map { $0.chain == nil }, [true, true, true, false])
        XCTAssertTrue(items[3].chain === alpha)
    }

    func testRouterPopsPushedScreenOrDismissesModalRoot() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let router = NetworkManagmentRouter()

        let pushed = UIViewController()
        host.navigation.pushViewController(pushed, animated: false)
        XCTAssertEqual(host.navigation.viewControllers.count, 2)
        router.dismiss(view: CovJNetBacked(pushed))
        XCTAssertTrue(CovJWait.until { host.navigation.viewControllers.count == 1 && host.navigation.transitionCoordinator == nil })
        XCTAssertTrue(host.top === host.controller)

        let modalRoot = UIViewController()
        host.controller.present(UINavigationController(rootViewController: modalRoot), animated: false)
        XCTAssertTrue(CovJWait.until { host.presented != nil })
        router.dismiss(view: CovJNetBacked(modalRoot))
        XCTAssertTrue(CovJWait.until { host.presented == nil })
    }
}
