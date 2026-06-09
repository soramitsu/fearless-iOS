import XCTest
import UIKit
import FearlessFoundation
import FearlessSecureStorage
@testable import fearless

final class OnboardingTests: XCTestCase {
    func testDidLoad_whenViewIsProvided_thenSetsUpInteractor() {
        let interactor = OnboardingInteractorInputSpy()
        let presenter = createPresenter(interactor: interactor)
        let view = OnboardingViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
    }

    func testDidReceiveOnboardingConfig_whenConfigArrives_thenBuildsAndPassesViewModel() throws {
        let expectedConfig = try Self.makeOnboardingConfig(minVersion: "2.0.0")
        let backgroundURL = try XCTUnwrap(URL(string: "https://fearlesswallet.io/background-test.png"))
        let factory = OnboardingPagesFactorySpy(
            dataSource: OnboardingDataSource(
                pages: [
                    OnboardingPageViewModel(
                        title: "Secure account",
                        titleColorHex: "#FFFFFF",
                        description: "Back up your wallet.",
                        imageViewModel: nil
                    )
                ],
                backgroundImage: RemoteImageViewModel(url: backgroundURL)
            )
        )
        let view = OnboardingViewSpy()
        let presenter = createPresenter(pagesFactory: factory)

        presenter.didLoad(view: view)
        presenter.didReceiveOnboardingConfig(expectedConfig)

        XCTAssertEqual(factory.receivedConfig?.minVersion, expectedConfig.minVersion)
        XCTAssertEqual(view.receivedViewModel?.pages.count, 1)
        XCTAssertEqual(view.receivedViewModel?.pages.first?.title, "Secure account")
        XCTAssertEqual(view.receivedViewModel?.backgroundImage?.url, backgroundURL)
    }

    func testDidTapSkipButton_whenStartViewRequiresLogin_thenClosesAndShowsLogin() {
        let interactor = OnboardingInteractorInputSpy()
        let router = OnboardingRouterSpy()
        let startViewHelper = StartViewHelperSpy(startView: .login)
        let presenter = createPresenter(
            interactor: interactor,
            router: router,
            startViewHelper: startViewHelper
        )

        presenter.didTapSkipButton()

        XCTAssertTrue(interactor.didCloseCalled)
        XCTAssertNil(startViewHelper.receivedConfig)
        XCTAssertEqual(router.routes, [.login])
    }

    func testDidTapSkipButton_whenStartViewRequiresPin_thenClosesAndShowsLocalAuthentication() {
        let interactor = OnboardingInteractorInputSpy()
        let router = OnboardingRouterSpy()
        let presenter = createPresenter(
            interactor: interactor,
            router: router,
            startViewHelper: StartViewHelperSpy(startView: .pin)
        )

        presenter.didTapSkipButton()

        XCTAssertTrue(interactor.didCloseCalled)
        XCTAssertEqual(router.routes, [.localAuthentication])
    }

    func testDidTapSkipButton_whenStartViewRequiresPinSetup_thenClosesAndShowsPincodeSetup() {
        let interactor = OnboardingInteractorInputSpy()
        let router = OnboardingRouterSpy()
        let presenter = createPresenter(
            interactor: interactor,
            router: router,
            startViewHelper: StartViewHelperSpy(startView: .pinSetup)
        )

        presenter.didTapSkipButton()

        XCTAssertTrue(interactor.didCloseCalled)
        XCTAssertEqual(router.routes, [.pincodeSetup])
    }

    func testInteractorDidClose_whenAppVersionIsAvailable_thenStoresLastShownVersion() throws {
        let storage = InMemorySettingsManager()
        let interactor = OnboardingInteractor(
            operationQueue: OperationQueue(),
            userDefaultsStorage: storage,
            config: try Self.makeOnboardingConfig()
        )

        interactor.didClose()

        XCTAssertEqual(
            storage.string(for: OnboardingKeys.lastShownOnboardingVersion.rawValue),
            AppVersion.stringValue
        )
    }

    private func createPresenter(
        interactor: OnboardingInteractorInput = OnboardingInteractorInputSpy(),
        router: OnboardingRouterInput = OnboardingRouterSpy(),
        pagesFactory: OnboardingPagesFactoryProtocol = OnboardingPagesFactorySpy(),
        startViewHelper: StartViewHelperProtocol = StartViewHelperSpy(startView: .login)
    ) -> OnboardingPresenter {
        OnboardingPresenter(
            interactor: interactor,
            router: router,
            pagesFactory: pagesFactory,
            startViewHelper: startViewHelper,
            localizationManager: LocalizationManager.shared
        )
    }
}

private final class OnboardingViewSpy: OnboardingViewInput {
    let controller = UIViewController()
    let isSetup = false
    private(set) var receivedViewModel: OnboardingDataSource?
    private(set) var showNextPageCallCount = 0

    func didReceive(viewModel: OnboardingDataSource) {
        receivedViewModel = viewModel
    }

    func showNextPage() {
        showNextPageCallCount += 1
    }
}

private final class OnboardingInteractorInputSpy: OnboardingInteractorInput {
    private(set) weak var output: OnboardingInteractorOutput?
    private(set) var didCloseCalled = false

    func setup(with output: OnboardingInteractorOutput) {
        self.output = output
    }

    func didClose() {
        didCloseCalled = true
    }
}

private final class OnboardingRouterSpy: OnboardingRouterInput {
    enum Route: Equatable {
        case main
        case localAuthentication
        case login
        case pincodeSetup
    }

    private(set) var routes: [Route] = []

    func showMain() {
        routes.append(.main)
    }

    func showLocalAuthentication() {
        routes.append(.localAuthentication)
    }

    func showLogin() {
        routes.append(.login)
    }

    func showPincodeSetup() {
        routes.append(.pincodeSetup)
    }
}

private final class OnboardingPagesFactorySpy: OnboardingPagesFactoryProtocol {
    private(set) var receivedConfig: OnboardingConfigWrapper?
    private let dataSource: OnboardingDataSource

    init(
        dataSource: OnboardingDataSource = OnboardingDataSource(
            pages: [],
            backgroundImage: nil
        )
    ) {
        self.dataSource = dataSource
    }

    func createPageControllers(
        with configWrapper: OnboardingConfigWrapper
    ) -> OnboardingDataSource {
        receivedConfig = configWrapper
        return dataSource
    }
}

private final class StartViewHelperSpy: StartViewHelperProtocol {
    private(set) var receivedConfig: OnboardingConfigWrapper?
    private let startView: StartView

    init(startView: StartView) {
        self.startView = startView
    }

    func startView(onboardingConfig: OnboardingConfigWrapper?) -> StartView {
        receivedConfig = onboardingConfig
        return startView
    }
}

private extension OnboardingTests {
    static func makeOnboardingConfig(minVersion: String = "1.0.0") throws -> OnboardingConfigWrapper {
        let page: [String: Any] = [
            "title": [
                "text": "Own your crypto",
                "color": "#FFFFFF"
            ],
            "description": "Start safely.",
            "image": "https://fearlesswallet.io/onboarding.png"
        ]

        let config: [String: Any] = [
            "new": [page],
            "regular": [page]
        ]

        let wrapper: [String: Any] = [
            "en-EN": config,
            "minVersion": minVersion,
            "background": "https://fearlesswallet.io/background.png"
        ]

        let data = try JSONSerialization.data(withJSONObject: ["iOS": [wrapper]], options: [])
        let platform = try JSONDecoder().decode(OnboardingConfigPlatform.self, from: data)
        return try XCTUnwrap(platform.ios.first)
    }
}
