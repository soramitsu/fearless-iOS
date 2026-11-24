import XCTest
import UIKit
import SoraFoundation
import SoraKeystore
@testable import fearless

enum CovJOnOnboardingFixture {
    static let imageURL = UniversalWalletRegistry.bitcoinIconURL

    static func config(minVersion: String = "1.0.0", pages: [[String: Any]]? = nil) throws -> OnboardingConfigWrapper {
        let defaultPages: [[String: Any]] = [
            ["title": ["text": "Own your keys", "color": "#FF0000"], "description": "First page", "image": imageURL.absoluteString],
            ["description": "Second page"]
        ]
        let json: [String: Any] = [
            "en-EN": ["new": pages ?? defaultPages, "regular": []],
            "minVersion": minVersion,
            "background": imageURL.absoluteString
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(OnboardingConfigWrapper.self, from: data)
    }
}

final class CovJOnOnboardingView: UIViewController, OnboardingViewInput {
    var dataSources: [OnboardingDataSource] = []
    var nextPages = 0
    func didReceive(viewModel: OnboardingDataSource) { dataSources.append(viewModel) }
    func showNextPage() { nextPages += 1 }
}

final class CovJOnOnboardingInteractor: OnboardingInteractorInput {
    let config: OnboardingConfigWrapper
    var closes = 0
    init(config: OnboardingConfigWrapper) { self.config = config }
    func setup(with output: OnboardingInteractorOutput) { output.didReceiveOnboardingConfig(config) }
    func didClose() { closes += 1 }
}

final class CovJOnOnboardingRouter: OnboardingRouterInput {
    var routes: [String] = []
    func showMain() { routes.append("main") }
    func showLocalAuthentication() { routes.append("pin") }
    func showLogin() { routes.append("login") }
    func showPincodeSetup() { routes.append("pinSetup") }
}

final class CovJOnStartViewStub: StartViewHelperProtocol {
    var result: Result<StartView, Error>
    init(_ result: Result<StartView, Error>) { self.result = result }
    func startView(onboardingConfig _: OnboardingConfigWrapper?) throws -> StartView { try result.get() }
}

final class CovJOnOnboardingOutput: OnboardingViewOutput {
    var loads = 0
    var skips = 0
    func didLoad(view _: OnboardingViewInput) { loads += 1 }
    func didTapSkipButton() { skips += 1 }
}

final class CovJOnOnboardingModuleTests: XCTestCase {
    func testPagesFactoryMapsTitlesColorsDescriptionsAndImages() throws {
        let config = try CovJOnOnboardingFixture.config()
        let dataSource = OnboardingPagesFactory().createPageControllers(with: config)
        XCTAssertEqual(dataSource.pages.map(\.title), ["Own your keys", nil])
        XCTAssertEqual(dataSource.pages.map(\.titleColorHex), ["#FF0000", nil])
        XCTAssertEqual(dataSource.pages.map(\.description), ["First page", "Second page"])
        XCTAssertEqual(dataSource.pages.first?.imageViewModel?.url, CovJOnOnboardingFixture.imageURL)
        XCTAssertNil(dataSource.pages.last?.imageViewModel)
        XCTAssertEqual(dataSource.backgroundImage?.url, CovJOnOnboardingFixture.imageURL)
    }

    func testPresenterDeliversPagesAndRoutesSkipByStartView() throws {
        let config = try CovJOnOnboardingFixture.config()
        let cases: [(Result<StartView, Error>, [String])] = [
            (.success(.pin), ["pin"]),
            (.success(.pinSetup), ["pinSetup"]),
            (.success(.login), ["login"]),
            (.success(.onboarding(config)), []),
            (.failure(StartViewError.selectedWalletUnavailable), [])
        ]
        for (result, expected) in cases {
            let interactor = CovJOnOnboardingInteractor(config: config)
            let router = CovJOnOnboardingRouter()
            let presenter = OnboardingPresenter(
                interactor: interactor,
                router: router,
                pagesFactory: OnboardingPagesFactory(),
                startViewHelper: CovJOnStartViewStub(result),
                localizationManager: LocalizationManager.shared
            )
            let view = CovJOnOnboardingView()
            presenter.didLoad(view: view)
            presenter.applyLocalization()
            XCTAssertEqual(view.dataSources.count, 1)
            XCTAssertEqual(view.dataSources.first?.pages.count, 2)
            presenter.didTapSkipButton()
            XCTAssertEqual(interactor.closes, 1)
            XCTAssertEqual(router.routes, expected)
        }
    }

    func testInteractorDeliversConfigAndRemembersShownVersion() throws {
        let config = try CovJOnOnboardingFixture.config(minVersion: "2.0.0")
        let storage = InMemorySettingsManager()
        let interactor = OnboardingInteractor(operationQueue: OperationQueue(), userDefaultsStorage: storage, config: config)
        let presenter = OnboardingPresenter(
            interactor: interactor,
            router: CovJOnOnboardingRouter(),
            pagesFactory: OnboardingPagesFactory(),
            startViewHelper: CovJOnStartViewStub(.success(.login)),
            localizationManager: LocalizationManager.shared
        )
        let view = CovJOnOnboardingView()
        presenter.didLoad(view: view)
        XCTAssertEqual(view.dataSources.first?.pages.first?.description, "First page")
        interactor.didClose()
        XCTAssertEqual(storage.string(for: OnboardingKeys.lastShownOnboardingVersion.rawValue), AppVersion.stringValue)
    }

    func testVersionResolverPicksOlderConfigUnlessAlreadyShown() throws {
        let current = try XCTUnwrap(AppVersion.stringValue)
        let older = try CovJOnOnboardingFixture.config(minVersion: "0.0.1")
        let newer = try CovJOnOnboardingFixture.config(minVersion: "999.0.0")
        let storage = InMemorySettingsManager()
        let resolver = OnboardingConfigVersionResolver(userDefaultsStorage: storage)

        XCTAssertEqual(resolver.resolve(configWrappers: [older, newer])?.minVersion, "0.0.1")
        XCTAssertNil(resolver.resolve(configWrappers: [newer]))
        XCTAssertNil(resolver.resolve(configWrappers: []))

        storage.set(value: "0.0.0", for: OnboardingKeys.lastShownOnboardingVersion.rawValue)
        XCTAssertEqual(resolver.resolve(configWrappers: [older])?.minVersion, "0.0.1")
        storage.set(value: "0.0.1", for: OnboardingKeys.lastShownOnboardingVersion.rawValue)
        XCTAssertNil(resolver.resolve(configWrappers: [older]))
        storage.set(value: current, for: OnboardingKeys.lastShownOnboardingVersion.rawValue)
        XCTAssertNil(resolver.resolve(configWrappers: [try CovJOnOnboardingFixture.config(minVersion: current)]))
    }

    func testAssemblyBuildsOnboardingController() throws {
        let module = try XCTUnwrap(OnboardingAssembly.configureModule(config: CovJOnOnboardingFixture.config()))
        let controller = try XCTUnwrap(module.view.controller as? OnboardingViewController)
        XCTAssertTrue(module.input is OnboardingPresenter)
        XCTAssertEqual(controller.rootView.pageControl.numberOfPages, 2, "Assigning localization loads the view, which asks for the pages")
    }
}

final class CovJOnOnboardingControllerTests: XCTestCase {
    private func show() throws -> (OnboardingViewController, CovJOnOnboardingOutput, UIWindow) {
        let output = CovJOnOnboardingOutput()
        let controller = OnboardingViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        return (controller, output, window)
    }

    func testPagesRenderAndButtonsAdvanceThenSkip() throws {
        let (controller, output, window) = try show()
        defer { window.isHidden = true }
        XCTAssertEqual(output.loads, 1)
        let dataSource = try OnboardingPagesFactory().createPageControllers(with: CovJOnOnboardingFixture.config())
        controller.didReceive(viewModel: dataSource)
        let root = controller.rootView
        root.layoutIfNeeded()
        XCTAssertEqual(root.pageControl.numberOfPages, 2)
        let collection = root.collectionView
        XCTAssertEqual(collection.dataSource?.collectionView(collection, numberOfItemsInSection: 0), 2)
        collection.reloadData()
        collection.layoutIfNeeded()
        let cell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 0, section: 0)) as? OnboardingPageCell)
        let texts = CovJViewFixture.descendants(UILabel.self, in: cell).compactMap(\.text)
        XCTAssertTrue(texts.contains("Own your keys"))
        XCTAssertTrue(texts.contains("First page"))

        root.nextButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.skips, 0, "The first page advances instead of skipping")
        root.pageControl.currentPage = 1
        root.nextButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.skips, 1)
        root.skipButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.skips, 2)
    }

    func testScrollingUpdatesPageAndLocalizationTitlesButtons() throws {
        let (controller, output, window) = try show()
        defer { window.isHidden = true }
        let root = controller.rootView
        let pages = (0 ..< 3).map { OnboardingPageViewModel(title: "P\($0)", titleColorHex: nil, description: nil, imageViewModel: nil) }
        controller.didReceive(viewModel: OnboardingDataSource(pages: pages, backgroundImage: nil))
        root.layoutIfNeeded()
        let width = root.collectionView.frame.width
        XCTAssertGreaterThan(width, 0)
        root.collectionView.contentOffset = CGPoint(x: width * 2, y: 0)
        controller.scrollViewDidScroll(root.collectionView)
        XCTAssertEqual(root.pageControl.currentPage, 2)
        controller.showNextPage()
        XCTAssertEqual(output.skips, 1)

        controller.localizationManager = LocalizationManager.shared
        controller.applyLocalization()
        let languages = controller.selectedLocale.rLanguages
        XCTAssertEqual(root.nextButton.imageWithTitleView?.title, R.string.localizable.commonNext(preferredLanguages: languages))
        XCTAssertEqual(root.skipButton.imageWithTitleView?.title, R.string.localizable.commonSkip(preferredLanguages: languages))
    }

    func testPageCellAppliesHexTitleColour() throws {
        let cell = OnboardingPageCell(frame: CGRect(x: 0, y: 0, width: 320, height: 500))
        cell.bind(viewModel: OnboardingPageViewModel(title: "Red", titleColorHex: "#FF0000", description: "Body", imageViewModel: nil))
        let labels = CovJViewFixture.descendants(UILabel.self, in: cell)
        let title = try XCTUnwrap(labels.first { $0.text == "Red" })
        XCTAssertEqual(title.textColor, HexColorConverter.hexStringToUIColor(hex: "#FF0000"))
        XCTAssertTrue(labels.contains { $0.text == "Body" })
        XCTAssertTrue(cell.clipsToBounds)
    }
}

final class CovJOnStartRouterSpy: OnboardingStartRouterInput {
    var configs: [OnboardingConfigWrapper] = []
    func startOnboarding(config: OnboardingConfigWrapper) { configs.append(config) }
}

final class CovJOnStartViewInputStub: UIViewController, OnboardingStartViewInput {}

final class CovJOnStartInteractorSpy: OnboardingStartInteractorInput {
    weak var output: OnboardingStartInteractorOutput?
    func setup(with output: OnboardingStartInteractorOutput) { self.output = output }
}

final class CovJOnOnboardingStartTests: XCTestCase {
    func testPresenterSetsUpInteractorAndStartsOnboardingWithItsConfig() throws {
        let config = try CovJOnOnboardingFixture.config(minVersion: "3.1.0")
        let router = CovJOnStartRouterSpy()
        let interactor = CovJOnStartInteractorSpy()
        let presenter = OnboardingStartPresenter(
            interactor: interactor,
            router: router,
            config: config,
            localizationManager: LocalizationManager.shared
        )
        presenter.didLoad(view: CovJOnStartViewInputStub())
        presenter.applyLocalization()
        XCTAssertTrue(interactor.output === presenter)
        presenter.didTapStartButton()
        XCTAssertEqual(router.configs.map(\.minVersion), ["3.1.0"])
    }

    func testAssemblyWiresRealInteractor() throws {
        let module = try XCTUnwrap(OnboardingStartAssembly.configureModule(CovJOnOnboardingFixture.config()))
        XCTAssertTrue(module.view.controller is OnboardingStartViewController)
        let presenter = try XCTUnwrap(module.input as? OnboardingStartPresenter)
        presenter.didLoad(view: CovJOnStartViewInputStub())
        let interactor = OnboardingStartInteractor()
        interactor.setup(with: presenter)
        XCTAssertFalse(module.view.controller.isViewLoaded)
    }
}

final class CovJOnRiskRouterSpy: BackupRiskWarningsRouterInput {
    var dismisses = 0
    var usernames: [String] = []
    func dismiss(view _: ControllerBackedProtocol?) { dismisses += 1 }
    func showCreateAccount(usernameModel: UsernameSetupModel, from _: ControllerBackedProtocol?) {
        usernames.append(usernameModel.username)
    }
}

final class CovJOnRiskInteractorSpy: BackupRiskWarningsInteractorInput {
    var setups = 0
    func setup(with _: BackupRiskWarningsInteractorOutput) { setups += 1 }
}

final class CovJOnRiskOutputSpy: BackupRiskWarningsViewOutput {
    var actions: [String] = []
    func didLoad(view _: BackupRiskWarningsViewInput) { actions.append("load") }
    func didBackButtonTapped() { actions.append("back") }
    func didContinueButtonTapped() { actions.append("continue") }
}

final class CovJOnBackupRiskTests: XCTestCase {
    func testControllerEnablesContinueOnlyAfterEveryAcknowledgement() throws {
        let output = CovJOnRiskOutputSpy()
        let controller = BackupRiskWarningsViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        controller.applyLocalization()
        let root = controller.rootView
        XCTAssertEqual(output.actions, ["load"])
        XCTAssertFalse(root.continueButton.isEnabled)
        root.confirm1Button.sendActions(for: .touchUpInside)
        root.confirm2Button.sendActions(for: .touchUpInside)
        XCTAssertFalse(root.continueButton.isEnabled)
        root.confirm3Button.sendActions(for: .touchUpInside)
        XCTAssertTrue(root.continueButton.isEnabled)
        root.confirm2Button.sendActions(for: .touchUpInside)
        XCTAssertFalse(root.confirm2Button.isChecked)
        XCTAssertFalse(root.continueButton.isEnabled)
        root.confirm2Button.sendActions(for: .touchUpInside)
        root.continueButton.sendActions(for: .touchUpInside)
        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.actions, ["load", "continue", "back"])
    }

    func testPresenterRoutesBackAndContinueWithWalletName() {
        let router = CovJOnRiskRouterSpy()
        let interactor = CovJOnRiskInteractorSpy()
        let presenter = BackupRiskWarningsPresenter(
            walletName: "Savings",
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared
        )
        let controller = BackupRiskWarningsViewController(output: CovJOnRiskOutputSpy(), localizationManager: LocalizationManager.shared)
        presenter.didLoad(view: controller)
        presenter.applyLocalization()
        presenter.didBackButtonTapped()
        presenter.didContinueButtonTapped()
        XCTAssertEqual(interactor.setups, 1)
        XCTAssertEqual(router.dismisses, 1)
        XCTAssertEqual(router.usernames, ["Savings"])
    }

    func testAssemblyAndRouterPushAccountCreation() throws {
        let module = try XCTUnwrap(BackupRiskWarningsAssembly.configureModule(walletName: "Main"))
        XCTAssertTrue(module.view.controller is BackupRiskWarningsViewController)
        XCTAssertTrue(module.input is BackupRiskWarningsPresenter)
        BackupRiskWarningsInteractor().setup(with: try XCTUnwrap(module.input as? BackupRiskWarningsPresenter))

        let host = try CovJHostedView()
        defer { host.close() }
        BackupRiskWarningsRouter().showCreateAccount(usernameModel: UsernameSetupModel(username: "Main"), from: host)
        XCTAssertTrue(host.top is AccountCreateViewController)
        BackupRiskWarningsRouter().showCreateAccount(usernameModel: UsernameSetupModel(username: "Main"), from: nil)
        XCTAssertEqual(host.navigation.viewControllers.count, 2)
    }
}
