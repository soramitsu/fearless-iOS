import XCTest
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
        // Ensure onboarding config resolver will treat onboarding as needed
        userDefaultsStorage.set(value: "0.0.0", for: OnboardingKeys.lastShownOnboardingVersion.rawValue)

        let presenter = createPresenter(wireframe: wireframe,
                                        settings: settings,
                                        keystore: keystore,
                                        userDefaultsStorage: userDefaultsStorage)

        let splashExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showSplash(splashView: any(), on: any())).then { _ in
                splashExpectation.fulfill()
            }
        }
        
        let onboardingExpectation = XCTestExpectation()
        
        stub(wireframe) { stub in
            when(stub.showOnboarding(on: any(), with: any())).then { _ in
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
        userDefaultsStorage.set(value: "0.0.0", for: OnboardingKeys.lastShownOnboardingVersion.rawValue)

        let presenter = createPresenter(wireframe: wireframe,
                                        settings: settings,
                                        keystore: keystore,
                                        userDefaultsStorage: userDefaultsStorage)
        
        let splashExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showSplash(splashView: any(), on: any())).then { _ in
                splashExpectation.fulfill()
            }
        }

        let pincodeExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showPincodeSetup(on: any())).then { _ in
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
        userDefaultsStorage.set(value: "0.0.0", for: OnboardingKeys.lastShownOnboardingVersion.rawValue)

        let presenter = createPresenter(wireframe: wireframe,
                                        settings: settings,
                                        keystore: keystore,
                                        userDefaultsStorage: userDefaultsStorage)
        
        let splashExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showSplash(splashView: any(), on: any())).then { _ in
                splashExpectation.fulfill()
            }
        }

        let mainScreenExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showLocalAuthentication(on: any())).then { _ in
                mainScreenExpectation.fulfill()
            }
        }

        // when

        presenter.loadOnLaunch()

        // then

        wait(for: [splashExpectation, mainScreenExpectation], timeout: Constants.defaultExpectationDuration)
    }

    private func createPresenter(wireframe: MockRootWireframeProtocol,
                                 settings: SelectedWalletSettings,
                                 keystore: KeystoreProtocol,
                                 userDefaultsStorage: SettingsManagerProtocol,
                                 migrators: [Migrating] = []
    ) -> RootPresenter {
        // Provide minimal onboarding dependencies
        struct OnboardingServiceStub: OnboardingServiceProtocol {
            func fetchConfigs() async throws -> OnboardingConfigPlatform {
                let data = Data("{\"ios\":[]}".utf8)
                return try JSONDecoder().decode(OnboardingConfigPlatform.self, from: data)
            }
        }
        let resolver = OnboardingConfigVersionResolver(userDefaultsStorage: userDefaultsStorage)

        let interactor = RootInteractor(chainRegistry: ChainRegistryFacade.sharedRegistry,
                                        settings: settings,
                                        applicationConfig: ApplicationConfig.shared,
                                        eventCenter: MockEventCenterProtocol(),
                                        migrators: migrators,
                                        onboardingService: OnboardingServiceStub(),
                                        onboardingConfigResolver: resolver)
        
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
