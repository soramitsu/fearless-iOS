import XCTest
@testable import fearless
import Cuckoo
import SoraKeystore

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

        let presenter = createPresenter(wireframe: wireframe,
                                        settings: settings,
                                        keystore: keystore)

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).showOnboarding(on: any()).then { _ in
                expectation.fulfill()
            }
        }

        // when

        presenter.interactor.decideModuleSynchroniously()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertFalse(try keystore.checkKey(for: KeystoreTag.pincode.rawValue))
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

        let presenter = createPresenter(wireframe: wireframe,
                                        settings: settings,
                                        keystore: keystore)

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).showPincodeSetup(on: any()).then { _ in
                expectation.fulfill()
            }
        }

        // when

        presenter.interactor.decideModuleSynchroniously()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
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

        let presenter = createPresenter(wireframe: wireframe,
                                        settings: settings,
                                        keystore: keystore)

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).showLocalAuthentication(on: any()).then { _ in
                expectation.fulfill()
            }
        }

        // when

        presenter.interactor.decideModuleSynchroniously()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }

    private func createPresenter(wireframe: MockRootWireframeProtocol,
                                 settings: SelectedWalletSettings,
                                 keystore: KeystoreProtocol,
                                 migrators: [Migrating] = []
    ) -> RootPresenter {
        let interactor = RootInteractor(settings: settings,
                                        keystore: keystore,
                                        applicationConfig: ApplicationConfig.shared,
                                        eventCenter: MockEventCenterProtocol(),
                                        migrators: migrators)
        let presenter = RootPresenter()

        presenter.view = UIWindow()
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        stub(wireframe) { stub in
            when(stub).showOnboarding(on: any()).thenDoNothing()
            when(stub).showLocalAuthentication(on: any()).thenDoNothing()
            when(stub).showPincodeSetup(on: any()).thenDoNothing()
            when(stub).showBroken(on: any()).thenDoNothing()
        }

        return presenter
    }
}
