import XCTest
import Foundation
@testable import fearless
import Cuckoo
import SoraKeystore
import SoraFoundation
import simd

class RootTests: XCTestCase {
    func testOnboardingDecision() throws {
        // given

        let wireframe = MockRootWireframeProtocol()

        let keystore = InMemoryKeychain()

        let expectedPincode = "123456"
        try keystore.saveKey(expectedPincode.data(using: .utf8)!,
                             with: KeystoreTag.pincode.rawValue)

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

        XCTAssertFalse(try keystore.checkKey(for: KeystoreTag.pincode.rawValue))
        wait(for: [splashExpectation, onboardingExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testPincodeSetupDecision() {
        // given

        let wireframe = MockRootWireframeProtocol()

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        let selectedAccount = AccountGenerator.generateMetaAccount()
        settings.save(value: selectedAccount)

        let keystore = InMemoryKeychain()
        let userDefaultsStorage = InMemorySettingsManager()

        let presenter = createPresenter(wireframe: wireframe,
                                        settings: settings,
                                        keystore: keystore,
                                        userDefaultsStorage: userDefaultsStorage)
        
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
        settings.save(value: selectedAccount)

        let expectedPincode = "123456"
        try keystore.saveKey(expectedPincode.data(using: .utf8)!,
                             with: KeystoreTag.pincode.rawValue)
        let userDefaultsStorage = InMemorySettingsManager()

        let presenter = createPresenter(wireframe: wireframe,
                                        settings: settings,
                                        keystore: keystore,
                                        userDefaultsStorage: userDefaultsStorage)
        
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
        }

        // when

        presenter.loadOnLaunch()

        // then

        wait(for: [splashExpectation, mainScreenExpectation], timeout: Constants.defaultExpectationDuration)
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
            onboardingConfigResolver: resolver
        )

        let startViewHelper = StartViewHelper(keystore: keystore,
                                              selectedWalletSettings: settings,
                                              userDefaultsStorage: userDefaultsStorage)
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

private final class StubOnboardingService: OnboardingServiceProtocol {
    var result: Result<OnboardingConfigPlatform, Error>

    init(result: Result<OnboardingConfigPlatform, Error>) {
        self.result = result
    }

    func fetchConfigs() async throws -> OnboardingConfigPlatform {
        try result.get()
    }
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
