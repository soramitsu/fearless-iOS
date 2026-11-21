import XCTest
import UIKit
import RobinHood
import SSFModels
import SoraFoundation
@testable import fearless

final class CovJBannersView: UIViewController, BannersViewInput {
    var models: [BannersViewModel] = []
    func didReceive(viewModel: BannersViewModel) { models.append(viewModel) }
}

final class CovJBannersInteractor: BannersInteractorInput {
    weak var output: BannersInteractorOutput?
    var backedUp: [MetaAccountModel] = []
    var subscriptions = 0
    func setup(with output: BannersInteractorOutput) { self.output = output }
    func markWalletAsBackedUp(_ wallet: MetaAccountModel) { backedUp.append(wallet) }
    func subscribeToWallet() { subscriptions += 1 }
}

final class CovJBannersRouter: CovJSheetSpy, BannersRouterInput {
    var backups: [String] = []
    var pools: [String] = []
    func showWalletBackupScreen(for wallet: MetaAccountModel, from _: ControllerBackedProtocol?) { backups.append(wallet.metaId) }
    func presentLiquidityPools(on _: ControllerBackedProtocol?, wallet _: MetaAccountModel, chainId: ChainModel.Id) { pools.append(chainId) }
}

final class CovJBannersModuleOutput: BannersModuleOutput {
    var reloads = 0
    var closes = 0
    func reloadBannersView() { reloads += 1 }
    func didTapCloseBanners() { closes += 1 }
}

final class CovJBannersViewOutput: BannersViewOutput {
    var loads = 0
    var taps: [Banners] = []
    var closes: [Banners] = []
    func didLoad(view _: BannersViewInput) { loads += 1 }
    func didTapOnBanner(_ banner: Banners) { taps.append(banner) }
    func didCloseBanner(_ banner: Banners) { closes.append(banner) }
}

final class CovJBannersTests: XCTestCase {
    private let locale = CovJFixture.locale

    private func presenter(
        type: BannersModuleType,
        wallet: MetaAccountModel?
    ) -> (BannersPresenter, CovJBannersView, CovJBannersInteractor, CovJBannersRouter, CovJBannersModuleOutput) {
        let interactor = CovJBannersInteractor()
        let router = CovJBannersRouter()
        let output = CovJBannersModuleOutput()
        let presenter = BannersPresenter(
            logger: Logger.shared,
            moduleOutput: output,
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            type: type,
            wallet: wallet
        )
        let view = CovJBannersView()
        presenter.didLoad(view: view)
        return (presenter, view, interactor, router, output)
    }

    func testFactoryBuildsEveryBannerKind() {
        let model = BannersViewModelFactory().createViewModel(banners: [.backup, .buyXor, .liquidityPools, .liquidityPoolsTest], locale: locale)
        XCTAssertEqual(model.banners.map(\.bannerType), [.backup, .buyXor, .liquidityPools, .liquidityPoolsTest])
        XCTAssertEqual(model.banners[0].title, R.string.localizable.bannersViewFactoryBackupTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(model.banners[0].buttonTitle, R.string.localizable.bannersViewFactoryBackupActionTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(model.banners[1].subtitle, R.string.localizable.bannersViewFactoryXorSubtitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(model.banners[2].title, R.string.localizable.balanceLocksLiquidityPoolsRowTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(model.banners[3].title, "Liquidity pools test")
        XCTAssertEqual(model.banners.map(\.fullsizeImage), [false, false, true, true])
        XCTAssertTrue(model.banners.allSatisfy(\.dismissable))
    }

    func testFactoryShowsBackupBannerOnlyForWalletsWithoutBackup() {
        let wallet = AccountGenerator.generateMetaAccount()
        let notBacked = wallet.replacingIsBackuped(false)
        let backed = wallet.replacingIsBackuped(true)
        let factory = BannersViewModelFactory()
        XCTAssertEqual(factory.createViewModel(wallet: notBacked, locale: locale).banners.map(\.bannerType), notBacked.hasBackup ? [] : [.backup])
        XCTAssertEqual(factory.createViewModel(wallet: backed, locale: locale).banners.map(\.bannerType), backed.hasBackup ? [] : [.backup])
    }

    func testIndependentPresenterSubscribesAndRoutesBannerActions() throws {
        let wallet = AccountGenerator.generateMetaAccount().replacingIsBackuped(false)
        let (presenter, view, interactor, router, output) = presenter(type: .independent, wallet: nil)
        XCTAssertEqual(interactor.subscriptions, 1)
        XCTAssertNotNil(interactor.output)
        presenter.didTapOnBanner(.backup)
        presenter.didCloseBanner(.backup)
        XCTAssertTrue(router.backups.isEmpty && router.sheets.isEmpty, "Without a wallet the banners do nothing")

        presenter.didReceive(wallet: wallet)
        XCTAssertEqual(output.reloads, 1)
        XCTAssertTrue(CovJWait.until { view.models.count == 1 })

        presenter.didTapOnBanner(.backup)
        presenter.didTapOnBanner(.buyXor)
        presenter.didTapOnBanner(.liquidityPools)
        presenter.didTapOnBanner(.liquidityPoolsTest)
        XCTAssertEqual(router.backups, [wallet.metaId])
        XCTAssertEqual(router.pools, [Chain.soraMain.genesisHash, Chain.soraTest.genesisHash])

        presenter.didCloseBanner(.buyXor)
        presenter.didCloseBanner(.liquidityPools)
        presenter.didCloseBanner(.liquidityPoolsTest)
        XCTAssertEqual(output.closes, 2)
        presenter.didCloseBanner(.backup)
        let sheet = try XCTUnwrap(router.sheets.last)
        XCTAssertEqual(sheet.title, R.string.localizable.backupNotBackedUpTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(sheet.message, R.string.localizable.backupNotBackedUpMessage(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(sheet.actions.count, 2)
        sheet.actions[1].handler?()
        XCTAssertEqual(interactor.backedUp.map(\.metaId), [wallet.metaId])

        presenter.didReceive(error: CovJError())
        presenter.applyLocalization()
        presenter.update(banners: [.liquidityPools])
        XCTAssertEqual(view.models.last?.banners.map(\.bannerType), [.liquidityPools])
        presenter.reload(with: wallet)
        XCTAssertEqual(output.reloads, 2)
    }

    func testEmbeddedPresenterDoesNotSubscribe() {
        let (_, _, interactor, _, _) = presenter(type: .embed, wallet: AccountGenerator.generateMetaAccount())
        XCTAssertEqual(interactor.subscriptions, 0)
    }

    func testViewControllerFillsCollectionAndForwardsCellButtons() throws {
        let output = CovJBannersViewOutput()
        let controller = BannersViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        XCTAssertEqual(output.loads, 1)
        let layout = try XCTUnwrap(controller.view as? BannersViewLayout)
        layout.frame = CGRect(x: 0, y: 0, width: 390, height: 180)
        let model = BannersViewModelFactory().createViewModel(banners: [.backup, .liquidityPools, .buyXor], locale: locale)
        controller.didReceive(viewModel: model)
        let collection = layout.collectionView
        XCTAssertEqual(collection.dataSource?.collectionView(collection, numberOfItemsInSection: 0), 3)
        XCTAssertEqual(layout.pageControl.numberOfPages, 3)
        collection.layoutIfNeeded()
        let cell = try XCTUnwrap(
            collection.dataSource?.collectionView(collection, cellForItemAt: IndexPath(item: 0, section: 0)) as? BannerCollectionViewCell
        )
        XCTAssertEqual(cell.titleLabel.text, model.banners[0].title)
        XCTAssertEqual(cell.subtitleLabel.text, model.banners[0].subtitle)
        XCTAssertEqual(cell.actionButton.imageWithTitleView?.title, model.banners[0].buttonTitle)
        XCTAssertFalse(cell.closeButton.isHidden)
        cell.actionButton.sendActions(for: .touchUpInside)
        cell.closeButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.taps, [.backup])
        XCTAssertEqual(output.closes, [.backup])

        let poolCell = try XCTUnwrap(
            collection.dataSource?.collectionView(collection, cellForItemAt: IndexPath(item: 1, section: 0)) as? BannerCollectionViewCell
        )
        poolCell.frame = CGRect(x: 0, y: 0, width: 358, height: 150)
        poolCell.layoutIfNeeded()
        XCTAssertEqual(poolCell.imageView.image, model.banners[1].image)

        collection.contentOffset = CGPoint(x: collection.frame.width * 2, y: 0)
        controller.scrollViewDidScroll(collection)
        XCTAssertEqual(layout.pageControl.currentPage, 2)
        controller.didActionButtonTapped(banner: .liquidityPools)
        controller.didCloseButtonTapped(banner: .buyXor)
        XCTAssertEqual(output.taps.last, .liquidityPools)
        XCTAssertEqual(output.closes.last, .buyXor)
        controller.applyLocalization()
        XCTAssertEqual(layout.locale, controller.selectedLocale)
        layout.setPageControl(pageCount: 1)
        XCTAssertTrue(layout.pageControl.isHidden)
        XCTAssertFalse(layout.collectionView.isHidden)
        layout.setPageControl(pageCount: 0)
        XCTAssertTrue(layout.collectionView.isHidden)
    }

    func testFlowLayoutSnapsToNearestPage() throws {
        let layout = DefaultFlowLayout()
        let collection = UICollectionView(frame: CGRect(x: 0, y: 0, width: 300, height: 120), collectionViewLayout: layout)
        let source = CollectionViewDataSource(data: [1, 2, 3], cellClass: UICollectionViewCell.self) { _, _ in }
        collection.registerClassForCell(UICollectionViewCell.self)
        collection.dataSource = source
        collection.layoutIfNeeded()
        layout.prepare()
        XCTAssertEqual(layout.scrollDirection, .horizontal)
        XCTAssertEqual(layout.itemSize.height, 120, accuracy: 0.5)
        let target = layout.targetContentOffset(forProposedContentOffset: CGPoint(x: 290, y: 0), withScrollingVelocity: .zero)
        XCTAssertEqual(target.x, layout.itemSize.width + 16, accuracy: 1)
        XCTAssertEqual(source.collectionView(collection, numberOfItemsInSection: 0), 3)
    }

    func testAssemblyBuildsEmbeddedModule() throws {
        let module = try XCTUnwrap(BannersAssembly.configureModule(output: nil, type: .embed, wallet: AccountGenerator.generateMetaAccount()))
        XCTAssertTrue(module.view.controller is BannersViewController)
        XCTAssertTrue(module.input is BannersPresenter)
    }
}
