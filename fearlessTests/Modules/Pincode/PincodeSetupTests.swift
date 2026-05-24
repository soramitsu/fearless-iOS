import XCTest
import UIKit
@testable import fearless
import FearlessSecureStorage

final class PincodeSetupTests: XCTestCase {
    func testDidLoad_whenViewLoads_thenDisablesAccessoryWithoutBiometry() {
        let fixture = createFixture(biometryType: .touchId)

        fixture.presenter.didLoad(view: fixture.view)

        XCTAssertEqual(fixture.view.accessoryChanges.count, 1)
        XCTAssertEqual(fixture.view.accessoryChanges.first?.enabled, false)
        assertBiometry(fixture.view.accessoryChanges.first?.type, equals: .none)
    }

    func testSubmit_whenBiometryUnavailable_thenSavesPinAndShowsMain() {
        let fixture = createFixture(biometryType: .none)
        let completionExpectation = expectSuccessfulCompletion(in: fixture)
        let expectedPin = "123456"

        fixture.presenter.didLoad(view: fixture.view)
        fixture.presenter.submit(pin: expectedPin)

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(fixture.secretStore.savedSecrets, [expectedPin])
        XCTAssertEqual(fixture.secretStore.savedIdentifiers, [KeystoreTag.pincode.rawValue])
        XCTAssertNil(fixture.settings.biometryEnabled)
        XCTAssertIdentical(fixture.wireframe.mainView as AnyObject, fixture.view)
    }

    func testSubmit_whenTouchIdAccepted_thenSavesPinAndEnablesBiometry() {
        let fixture = createFixture(biometryType: .touchId)
        let biometryExpectation = expectation(description: "Touch ID decision requested")
        let completionExpectation = expectSuccessfulCompletion(in: fixture)
        let expectedPin = "654321"

        fixture.view.onRequestBiometry = {
            biometryExpectation.fulfill()
        }

        fixture.presenter.didLoad(view: fixture.view)
        fixture.presenter.submit(pin: expectedPin)

        wait(for: [biometryExpectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertTrue(fixture.secretStore.savedSecrets.isEmpty)
        XCTAssertEqual(fixture.view.biometryRequests.count, 1)
        assertBiometry(fixture.view.biometryRequests.first?.type, equals: .touchId)

        fixture.view.completeLastBiometryRequest(with: true)
        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(fixture.secretStore.savedSecrets, [expectedPin])
        XCTAssertEqual(fixture.settings.biometryEnabled, true)
    }

    func testSubmit_whenTouchIdDeclined_thenSavesPinAndDisablesBiometry() {
        let fixture = createFixture(biometryType: .touchId)
        let biometryExpectation = expectation(description: "Touch ID decision requested")
        let completionExpectation = expectSuccessfulCompletion(in: fixture)

        fixture.view.onRequestBiometry = {
            biometryExpectation.fulfill()
        }

        fixture.presenter.didLoad(view: fixture.view)
        fixture.presenter.submit(pin: "111111")

        wait(for: [biometryExpectation], timeout: Constants.defaultExpectationDuration)
        fixture.view.completeLastBiometryRequest(with: false)
        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(fixture.secretStore.savedSecrets, ["111111"])
        XCTAssertEqual(fixture.settings.biometryEnabled, false)
    }

    func testSubmit_whenFaceIdAccepted_thenAuthenticatesAndEnablesBiometry() {
        let fixture = createFixture(biometryType: .faceId)
        let authenticationExpectation = expectation(description: "Face ID authentication requested")
        let completionExpectation = expectSuccessfulCompletion(in: fixture)

        fixture.biometry.onAuthenticate = {
            authenticationExpectation.fulfill()
        }

        fixture.presenter.didLoad(view: fixture.view)
        fixture.presenter.submit(pin: "222222")

        wait(for: [authenticationExpectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(fixture.view.biometryRequests.count, 0)
        XCTAssertTrue(fixture.secretStore.savedSecrets.isEmpty)
        XCTAssertFalse(fixture.biometry.localizedReasons.first?.isEmpty ?? true)

        fixture.biometry.completeAuthentication(with: true)
        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(fixture.secretStore.savedSecrets, ["222222"])
        XCTAssertEqual(fixture.settings.biometryEnabled, true)
    }

    func testSubmit_whenWaitingForBiometry_thenIgnoresAdditionalPins() {
        let fixture = createFixture(biometryType: .touchId)
        let biometryExpectation = expectation(description: "Touch ID decision requested")
        let completionExpectation = expectSuccessfulCompletion(in: fixture)

        fixture.view.onRequestBiometry = {
            biometryExpectation.fulfill()
        }

        fixture.presenter.didLoad(view: fixture.view)
        fixture.presenter.submit(pin: "333333")
        fixture.presenter.submit(pin: "999999")

        wait(for: [biometryExpectation], timeout: Constants.defaultExpectationDuration)
        fixture.view.completeLastBiometryRequest(with: true)
        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(fixture.secretStore.savedSecrets, ["333333"])
        XCTAssertEqual(fixture.settings.biometryEnabled, true)
    }

    private func createFixture(biometryType: AvailableBiometryType) -> PincodeSetupFixture {
        let view = PinSetupViewSpy()
        let wireframe = PinSetupWireframeSpy()
        let secretStore = SecretStoreManagerSpy()
        let biometry = BiometryAuthSpy(availableBiometryType: biometryType)
        let settings = InMemorySettingsManager()
        let interactor = PinSetupInteractor(
            secretManager: secretStore,
            settingsManager: settings,
            biometryAuth: biometry,
            locale: Locale(identifier: "en")
        )
        let presenter = PinSetupPresenter(interactor: interactor, wireframe: wireframe)
        interactor.presenter = presenter

        return PincodeSetupFixture(
            view: view,
            wireframe: wireframe,
            secretStore: secretStore,
            biometry: biometry,
            settings: settings,
            interactor: interactor,
            presenter: presenter
        )
    }

    private func expectSuccessfulCompletion(in fixture: PincodeSetupFixture) -> XCTestExpectation {
        let expectation = expectation(description: "Pincode setup completed")
        expectation.expectedFulfillmentCount = 2

        fixture.view.onStartLoading = {
            expectation.fulfill()
        }

        fixture.wireframe.onShowMain = {
            expectation.fulfill()
        }

        return expectation
    }

    private func assertBiometry(
        _ actual: AvailableBiometryType?,
        equals expected: AvailableBiometryType,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("Expected \(description(for: expected)), got nil", file: file, line: line)
            return
        }

        switch (actual, expected) {
        case (.none, .none), (.touchId, .touchId), (.faceId, .faceId):
            return
        default:
            XCTFail(
                "Expected \(description(for: expected)), got \(description(for: actual))",
                file: file,
                line: line
            )
        }
    }

    private func description(for biometryType: AvailableBiometryType) -> String {
        switch biometryType {
        case .none:
            return "none"
        case .touchId:
            return "touchId"
        case .faceId:
            return "faceId"
        }
    }
}

private struct PincodeSetupFixture {
    let view: PinSetupViewSpy
    let wireframe: PinSetupWireframeSpy
    let secretStore: SecretStoreManagerSpy
    let biometry: BiometryAuthSpy
    let settings: InMemorySettingsManager
    let interactor: PinSetupInteractor
    let presenter: PinSetupPresenter
}

private final class PinSetupViewSpy: PinSetupViewProtocol {
    let controller = UIViewController()
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true

    var isSetup: Bool {
        controller.isViewLoaded
    }

    var accessoryChanges: [(enabled: Bool, type: AvailableBiometryType)] = []
    var biometryRequests: [(type: AvailableBiometryType, completionBlock: (Bool) -> Void)] = []
    var startLoadingCount = 0
    var stopLoadingCount = 0
    var wrongPincodeCount = 0
    var onRequestBiometry: (() -> Void)?
    var onStartLoading: (() -> Void)?

    func didRequestBiometryUsage(
        biometryType: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void
    ) {
        biometryRequests.append((biometryType, completionBlock))
        onRequestBiometry?()
    }

    func didChangeAccessoryState(enabled: Bool, availableBiometryType: AvailableBiometryType) {
        accessoryChanges.append((enabled, availableBiometryType))
    }

    func didReceiveWrongPincode() {
        wrongPincodeCount += 1
    }

    func didStartLoading() {
        startLoadingCount += 1
        onStartLoading?()
    }

    func didStopLoading() {
        stopLoadingCount += 1
    }

    func completeLastBiometryRequest(with result: Bool) {
        guard let request = biometryRequests.last else {
            XCTFail("Expected a biometry request")
            return
        }

        request.completionBlock(result)
    }
}

private final class PinSetupWireframeSpy: PinSetupWireframeProtocol {
    var mainView: PinSetupViewProtocol?
    var showMainCount = 0
    var showSignupCount = 0
    var onShowMain: (() -> Void)?

    func showMain(from view: PinSetupViewProtocol?) {
        mainView = view
        showMainCount += 1
        onShowMain?()
    }

    func showSignup(from _: PinSetupViewProtocol?) {
        showSignupCount += 1
    }
}

private final class SecretStoreManagerSpy: SecretStoreManagerProtocol {
    var savedSecrets: [String] = []
    var savedIdentifiers: [String] = []

    func loadSecret(
        for _: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (SecretDataRepresentable?) -> Void
    ) {
        completionQueue.async {
            completionBlock(nil)
        }
    }

    func saveSecret(
        _ secret: SecretDataRepresentable,
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        savedSecrets.append(secret.toUTF8String() ?? "")
        savedIdentifiers.append(identifier)

        completionQueue.async {
            completionBlock(true)
        }
    }

    func removeSecret(
        for _: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        completionQueue.async {
            completionBlock(true)
        }
    }

    func checkSecret(
        for _: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        completionQueue.async {
            completionBlock(false)
        }
    }

    func checkSecret(for _: String) -> Bool {
        false
    }
}

private final class BiometryAuthSpy: BiometryAuthProtocol {
    let availableBiometryType: AvailableBiometryType
    var localizedReasons: [String] = []
    var completionQueue: DispatchQueue?
    var completionBlock: ((Bool) -> Void)?
    var onAuthenticate: (() -> Void)?

    init(availableBiometryType: AvailableBiometryType) {
        self.availableBiometryType = availableBiometryType
    }

    func authenticate(
        localizedReason: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        localizedReasons.append(localizedReason)
        self.completionQueue = completionQueue
        self.completionBlock = completionBlock
        onAuthenticate?()
    }

    func completeAuthentication(with result: Bool) {
        guard let completionQueue, let completionBlock else {
            XCTFail("Expected a pending authentication request")
            return
        }

        completionQueue.async {
            completionBlock(result)
        }
    }
}
