import XCTest
import Foundation
@testable import fearless
import Cuckoo
import FearlessSecureStorage
import FearlessFoundation
import SSFUtils
import simd

class RootTests: XCTestCase {
    func testOnboardingDecision() throws {
        // given

        let wireframe = MockRootWireframeProtocol()

        let keystore = InMemoryKeychain()

        let expectedPincode = "123456"
        try keystore.saveKey(
            expectedPincode.data(using: .utf8)!,
            with: KeystoreTag.pincode.rawValue
        )

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )
        let userDefaultsStorage = InMemorySettingsManager()

        let onboardingService = StubOnboardingService(
            result: .success(Self.makeOnboardingPlatform())
        )

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: settings,
            keystore: keystore,
            userDefaultsStorage: userDefaultsStorage,
            onboardingService: onboardingService
        )

        let splashExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.showSplash(splashView: any(), on: any()).then { _ in
                splashExpectation.fulfill()
            }
        }

        let onboardingExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.showOnboarding(on: any(), with: any()).then { _ in
                onboardingExpectation.fulfill()
            }
        }

        // when

        presenter.loadOnLaunch()

        // then

        wait(for: [splashExpectation, onboardingExpectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertTrue(try keystore.checkKey(for: KeystoreTag.pincode.rawValue))
    }

    func testPincodeSetupDecision() {
        // given

        let wireframe = MockRootWireframeProtocol()

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        let selectedAccount = AccountGenerator.generateMetaAccount()
        let saveExpectation = XCTestExpectation()
        settings.save(value: selectedAccount, runningCompletionIn: .main) { result in
            if case let .failure(error) = result {
                XCTFail("Unexpected save error: \(error)")
            }
            saveExpectation.fulfill()
        }
        wait(for: [saveExpectation], timeout: Constants.defaultExpectationDuration)

        let keystore = InMemoryKeychain()
        let userDefaultsStorage = InMemorySettingsManager()

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: settings,
            keystore: keystore,
            userDefaultsStorage: userDefaultsStorage
        )

        let splashExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.showSplash(splashView: any(), on: any()).then { _ in
                splashExpectation.fulfill()
            }
        }

        let pincodeExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.showPincodeSetup(on: any()).then { _ in
                pincodeExpectation.fulfill()
            }
            stub.showMain(on: any()).thenDoNothing()
        }

        // when

        presenter.loadOnLaunch()

        // then

        wait(for: [splashExpectation, pincodeExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testMainScreenDecision() throws {
        // given

        let wireframe = MockRootWireframeProtocol()

        let keystore = InMemoryKeychain()

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        let selectedAccount = AccountGenerator.generateMetaAccount()
        let saveExpectation = XCTestExpectation()
        settings.save(value: selectedAccount, runningCompletionIn: .main) { result in
            if case let .failure(error) = result {
                XCTFail("Unexpected save error: \(error)")
            }
            saveExpectation.fulfill()
        }
        wait(for: [saveExpectation], timeout: Constants.defaultExpectationDuration)

        let expectedPincode = "123456"
        try keystore.saveKey(
            expectedPincode.data(using: .utf8)!,
            with: KeystoreTag.pincode.rawValue
        )
        let userDefaultsStorage = InMemorySettingsManager()

        let presenter = createPresenter(
            wireframe: wireframe,
            settings: settings,
            keystore: keystore,
            userDefaultsStorage: userDefaultsStorage
        )

        let splashExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.showSplash(splashView: any(), on: any()).then { _ in
                splashExpectation.fulfill()
            }
        }

        let mainScreenExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.showLocalAuthentication(on: any()).then { _ in
                mainScreenExpectation.fulfill()
            }
            stub.showMain(on: any()).thenDoNothing()
        }

        // when

        presenter.loadOnLaunch()

        // then

        wait(for: [splashExpectation, mainScreenExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testSetup_whenCalled_thenConfiguresInjectedURLHandlingRegistry() {
        // given

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        let chainRegistry = MockChainRegistryProtocol()
        stub(chainRegistry) { stub in
            stub.performColdBoot().thenDoNothing()
            stub.performHotBoot().thenDoNothing()
        }

        let urlHandlingRegistry = URLHandlingRegistrySpy()
        let keystoreImportService = KeystoreImportServiceStub()

        let interactor = RootInteractor(
            chainRegistry: chainRegistry,
            settings: settings,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrators: [],
            logger: LoggerSpy(),
            onboardingService: StubOnboardingService(result: .failure(OnboardingServiceError.empty)),
            onboardingConfigResolver: OnboardingConfigVersionResolver(userDefaultsStorage: InMemorySettingsManager()),
            urlHandlingRegistry: urlHandlingRegistry,
            keystoreImportServiceFactory: { keystoreImportService }
        )

        // when

        interactor.setup(runMigrations: false)

        // then

        let configuredChildren = urlHandlingRegistry.configuredChildren
        XCTAssertEqual(configuredChildren.count, 2)
        XCTAssertTrue(configuredChildren[0] is PurchaseCompletionHandler)
        XCTAssertTrue(configuredChildren[1] === keystoreImportService)
    }

    private func createPresenter(
        wireframe: MockRootWireframeProtocol,
        settings: SelectedWalletSettings,
        keystore: KeystoreProtocol,
        userDefaultsStorage: SettingsManagerProtocol,
        migrators: [Migrating] = [],
        onboardingService: OnboardingServiceProtocol = StubOnboardingService(result: .failure(OnboardingServiceError.empty))
    ) -> RootPresenter {
        let resolver = OnboardingConfigVersionResolver(userDefaultsStorage: userDefaultsStorage)

        let interactor = RootInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            settings: settings,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: MockEventCenterProtocol(),
            migrators: migrators,
            onboardingService: onboardingService,
            onboardingConfigResolver: resolver,
            urlHandlingRegistry: URLHandlingRegistrySpy(),
            keystoreImportServiceFactory: { KeystoreImportServiceStub() }
        )

        let startViewHelper = StartViewHelper(
            keystore: keystore,
            selectedWalletSettings: settings,
            userDefaultsStorage: userDefaultsStorage
        )
        let presenter = RootPresenter(localizationManager: LocalizationManager.shared, startViewHelper: startViewHelper)

        let view = MockControllerBackedProtocol()

        presenter.view = view
        presenter.window = UIWindow()
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        return presenter
    }
}

final class OnboardingServiceTests: XCTestCase {
    func testFetchConfigs_whenConfigURLMissing_thenThrowsAndSkipsFetcher() async {
        let fetcher = OnboardingConfigFetcherSpy(result: .success(Self.makeOnboardingPlatform()))
        let service = makeService(configURL: nil, fetcher: fetcher)

        do {
            _ = try await service.fetchConfigs()
            XCTFail("Expected missing onboarding config URL to fail")
        } catch OnboardingServiceError.urlBroken {
            XCTAssertTrue(fetcher.requestedURLs.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchConfigs_whenConfigURLExists_thenFetchesInjectedURL() async throws {
        let expectedURL = URL(string: "https://example.com/onboarding.json")!
        let expectedConfig = Self.makeOnboardingPlatform()
        let fetcher = OnboardingConfigFetcherSpy(result: .success(expectedConfig))
        let service = makeService(configURL: expectedURL, fetcher: fetcher)

        let config = try await service.fetchConfigs()

        XCTAssertEqual(fetcher.requestedURLs, [expectedURL])
        XCTAssertEqual(config.ios.count, expectedConfig.ios.count)
        XCTAssertEqual(config.ios.first?.minVersion, expectedConfig.ios.first?.minVersion)
        XCTAssertEqual(config.ios.first?.background, expectedConfig.ios.first?.background)
    }

    private func makeService(
        configURL: URL?,
        fetcher: OnboardingConfigFetching
    ) -> OnboardingService {
        OnboardingService(
            configSource: OnboardingConfigSourceStub(onboardingConfig: configURL),
            configFetcher: fetcher
        )
    }

    private static func makeOnboardingPlatform() -> OnboardingConfigPlatform {
        let page: [String: Any] = [
            "description": "Test",
            "image": "https://fearlesswallet.io/onboarding.png"
        ]

        let config: [String: Any] = [
            "new": [page],
            "regular": [page]
        ]

        let wrapper: [String: Any] = [
            "en-EN": config,
            "minVersion": AppVersion.stringValue ?? "0.0.0",
            "background": "https://fearlesswallet.io/background.png"
        ]

        let payload: [String: Any] = ["iOS": [wrapper]]

        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        return try! JSONDecoder().decode(OnboardingConfigPlatform.self, from: data)
    }
}

private final class StubOnboardingService: OnboardingServiceProtocol {
    var result: Result<OnboardingConfigPlatform, Error>

    init(result: Result<OnboardingConfigPlatform, Error>) {
        self.result = result
    }

    func fetchConfigs() async throws -> OnboardingConfigPlatform {
        try result.get()
    }
}

private final class URLHandlingRegistrySpy: URLHandlingRegistryProtocol {
    private(set) var configuredChildren: [URLHandlingServiceProtocol] = []

    func setup(children: [URLHandlingServiceProtocol]) {
        configuredChildren = children
    }

    func findService<T>() -> T? {
        configuredChildren.first { $0 is T } as? T
    }

    func handle(url: URL) -> Bool {
        configuredChildren.contains { $0.handle(url: url) }
    }
}

private final class KeystoreImportServiceStub: KeystoreImportServiceProtocol {
    var definition: KeystoreDefinition?

    func add(observer _: KeystoreImportObserver) {}

    func remove(observer _: KeystoreImportObserver) {}

    func clear() {
        definition = nil
    }

    func handle(url _: URL) -> Bool {
        false
    }
}

private struct OnboardingConfigSourceStub: OnboardingConfigSource {
    let onboardingConfig: URL?
}

private final class OnboardingConfigFetcherSpy: OnboardingConfigFetching {
    private let result: Result<OnboardingConfigPlatform, Error>
    private(set) var requestedURLs: [URL] = []

    init(result: Result<OnboardingConfigPlatform, Error>) {
        self.result = result
    }

    func fetchConfig(from url: URL) async throws -> OnboardingConfigPlatform {
        requestedURLs.append(url)
        return try result.get()
    }
}

private final class LoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}

    func debug(message _: String, file _: String, function _: String, line _: Int) {}

    func info(message _: String, file _: String, function _: String, line _: Int) {}

    func warning(message _: String, file _: String, function _: String, line _: Int) {}

    func error(message _: String, file _: String, function _: String, line _: Int) {}

    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}

private extension RootTests {
    static func makeOnboardingPlatform() -> OnboardingConfigPlatform {
        let page: [String: Any] = [
            "description": "Test",
            "image": "https://fearlesswallet.io/onboarding.png"
        ]

        let config: [String: Any] = [
            "new": [page],
            "regular": [page]
        ]

        let wrapper: [String: Any] = [
            "en-EN": config,
            "minVersion": AppVersion.stringValue ?? "0.0.0",
            "background": "https://fearlesswallet.io/background.png"
        ]

        let payload: [String: Any] = ["iOS": [wrapper]]

        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        return try! JSONDecoder().decode(OnboardingConfigPlatform.self, from: data)
    }
}
