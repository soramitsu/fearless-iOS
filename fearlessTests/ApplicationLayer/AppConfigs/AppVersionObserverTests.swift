import Foundation
import RobinHood
import XCTest
@testable import fearless

final class AppVersionObserverTests: XCTestCase {
    func testCheckVersion_whenConfigURLMissing_thenDoesNotFetchOrEnqueue() {
        let fetcher = AppSupportConfigFetcherStub(result: .success(nil))
        let operationManager = AppVersionOperationManagerSpy()
        let observer = createObserver(
            operationManager: operationManager,
            configSource: AppVersionConfigSourceStub(appVersionURL: nil),
            configFetcher: fetcher
        )

        observer.checkVersion(from: nil, callback: nil)

        XCTAssertTrue(fetcher.requestedURLs.isEmpty)
        XCTAssertTrue(operationManager.enqueuedOperationCounts.isEmpty)
    }

    func testCheckVersion_whenVersionSupported_thenReportsSupportedWithoutWarning() {
        let callbackExpectation = expectation(description: "version check callback")
        let url = URL(string: "https://example.com/app-version.json")!
        let wireframe = AppVersionWireframeSpy()
        let observer = createObserver(
            wireframe: wireframe,
            configSource: AppVersionConfigSourceStub(appVersionURL: url),
            configFetcher: AppSupportConfigFetcherStub(
                result: .success(
                    AppSupportConfig(
                        minSupportedVersion: "2.0.6",
                        excludedVersions: ["2.0.3", "2.0.7"]
                    )
                )
            )
        )

        observer.checkVersion(from: nil) { supported, error in
            XCTAssertEqual(supported, true)
            XCTAssertNil(error)
            callbackExpectation.fulfill()
        }

        wait(for: [callbackExpectation], timeout: 5)

        XCTAssertTrue(wireframe.warningConfigs.isEmpty)
        XCTAssertEqual(wireframe.appStoreUpdateCallCount, 0)
    }

    func testCheckVersion_whenVersionUnsupported_thenPresentsWarningAndReportsUnsupported() {
        let callbackExpectation = expectation(description: "version check callback")
        let url = URL(string: "https://example.com/app-version.json")!
        let fetcher = AppSupportConfigFetcherStub(
            result: .success(
                AppSupportConfig(
                    minSupportedVersion: "2.0.6",
                    excludedVersions: []
                )
            )
        )
        let operationManager = AppVersionOperationManagerSpy()
        let wireframe = AppVersionWireframeSpy()
        let observer = createObserver(
            currentAppVersion: "2.0.2",
            operationManager: operationManager,
            wireframe: wireframe,
            configSource: AppVersionConfigSourceStub(appVersionURL: url),
            configFetcher: fetcher
        )

        observer.checkVersion(from: nil) { supported, error in
            XCTAssertEqual(supported, false)
            XCTAssertNil(error)
            callbackExpectation.fulfill()
        }

        wait(for: [callbackExpectation], timeout: 5)

        XCTAssertEqual(fetcher.requestedURLs, [url])
        XCTAssertEqual(operationManager.enqueuedOperationCounts, [1])
        XCTAssertEqual(operationManager.enqueuedModes.map(\.isTransient), [true])
        XCTAssertEqual(wireframe.warningConfigs.count, 1)

        wireframe.lastButtonHandler?()

        XCTAssertEqual(wireframe.appStoreUpdateCallCount, 1)
    }

    func testCheckVersion_whenFetcherFails_thenReportsErrorWithoutWarning() {
        let callbackExpectation = expectation(description: "version check callback")
        let testError = NSError(domain: "AppVersionObserverTests", code: 1)
        let wireframe = AppVersionWireframeSpy()
        let observer = createObserver(
            wireframe: wireframe,
            configFetcher: AppSupportConfigFetcherStub(result: .failure(testError))
        )

        observer.checkVersion(from: nil) { supported, error in
            XCTAssertNil(supported)
            XCTAssertEqual(error as NSError?, testError)
            callbackExpectation.fulfill()
        }

        wait(for: [callbackExpectation], timeout: 5)

        XCTAssertTrue(wireframe.warningConfigs.isEmpty)
        XCTAssertEqual(wireframe.appStoreUpdateCallCount, 0)
    }

    private func createObserver(
        currentAppVersion: String? = "2.0.8",
        operationManager: AppVersionOperationManagerSpy = AppVersionOperationManagerSpy(),
        wireframe: AppVersionWireframeSpy = AppVersionWireframeSpy(),
        configSource: AppVersionConfigSource = AppVersionConfigSourceStub(
            appVersionURL: URL(string: "https://example.com/app-version.json")!
        ),
        configFetcher: AppSupportConfigFetching = AppSupportConfigFetcherStub(result: .success(nil))
    ) -> AppVersionObserver {
        AppVersionObserver(
            operationManager: operationManager,
            currentAppVersion: currentAppVersion,
            wireframe: wireframe,
            locale: Locale(identifier: "en"),
            configSource: configSource,
            configFetcher: configFetcher,
            callbackQueue: .main
        )
    }
}

private struct AppVersionConfigSourceStub: AppVersionConfigSource {
    let appVersionURL: URL?
}

private final class AppSupportConfigFetcherStub: AppSupportConfigFetching {
    private let result: Result<AppSupportConfig?, Error>
    private(set) var requestedURLs: [URL] = []

    init(result: Result<AppSupportConfig?, Error>) {
        self.result = result
    }

    func fetchAppSupportConfig(from url: URL) -> CompoundOperationWrapper<AppSupportConfig?> {
        requestedURLs.append(url)

        switch result {
        case let .success(config):
            return .createWithResult(config)
        case let .failure(error):
            return .createWithError(error)
        }
    }
}

private final class AppVersionOperationManagerSpy: OperationManagerProtocol {
    private let operationQueue = OperationQueue()
    private(set) var enqueuedOperationCounts: [Int] = []
    private(set) var enqueuedModes: [OperationMode] = []

    func enqueue(operations: [Operation], in mode: OperationMode) {
        enqueuedOperationCounts.append(operations.count)
        enqueuedModes.append(mode)
        operationQueue.addOperations(operations, waitUntilFinished: false)
    }
}

private final class AppVersionWireframeSpy: AppVersionWireframe {
    private(set) var warningConfigs: [WarningAlertConfig] = []
    private(set) var appStoreUpdateCallCount = 0
    private(set) var dismissCallCount = 0
    private(set) var dismissedView: ControllerBackedProtocol?
    private(set) var lastButtonHandler: WarningAlertButtonHandler?

    func presentWarningAlert(
        from _: ControllerBackedProtocol?,
        config: WarningAlertConfig,
        buttonHandler: @escaping WarningAlertButtonHandler
    ) {
        warningConfigs.append(config)
        lastButtonHandler = buttonHandler
    }

    func showAppstoreUpdatePage() {
        appStoreUpdateCallCount += 1
    }

    func dismiss(view: ControllerBackedProtocol?) {
        dismissCallCount += 1
        dismissedView = view
    }
}

private extension OperationMode {
    var isTransient: Bool {
        if case .transient = self {
            return true
        }

        return false
    }
}
