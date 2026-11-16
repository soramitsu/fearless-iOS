import RobinHood
import XCTest
@testable import fearless

final class CovFMiscAppVersionTests: XCTestCase {
    func testSupportedVersionReportsTrueWithoutWarning() throws {
        let fixture = CovFMiscVersionFixture(version: "3.1.0")
        let outcome = try fixture.check(config: .success(fixture.config(min: "3.0.9", excluded: ["3.0.0"])))
        XCTAssertEqual(outcome.supported, true)
        XCTAssertNil(outcome.error)
        XCTAssertTrue(fixture.wireframe.warnings.isEmpty)
        XCTAssertEqual(fixture.manager.enqueued.count, 2)
    }

    func testExcludedOrTooOldVersionShowsWarningThatOpensStore() throws {
        for (min, excluded) in [("1.0.0", ["2.0.0"]), ("2.1.0", [String]())] {
            let fixture = CovFMiscVersionFixture(version: "2.0.0")
            let outcome = try fixture.check(config: .success(fixture.config(min: min, excluded: excluded)))
            XCTAssertEqual(outcome.supported, false)
            let warning = try XCTUnwrap(fixture.wireframe.warnings.first)
            XCTAssertEqual(warning.title, WarningAlertConfig.unsupportedAppVersionConfig(with: Locale(identifier: "en")).title)
            XCTAssertTrue(warning.blocksUi)
            XCTAssertEqual(fixture.wireframe.storeOpens, 0)
            fixture.wireframe.handlers.first?()
            XCTAssertEqual(fixture.wireframe.storeOpens, 1)
        }
    }

    func testMissingConfigIsTreatedAsSupportedAndFailureForwardsError() throws {
        let fixture = CovFMiscVersionFixture(version: "1.0.0")
        let supported = try fixture.check(config: .success(nil))
        XCTAssertEqual(supported.supported, true)
        let error = NSError(domain: "version", code: 2)
        let failed = try CovFMiscVersionFixture(version: "1.0.0").check(config: .failure(error))
        XCTAssertNil(failed.supported)
        XCTAssertEqual(failed.error as NSError?, error)
    }

    func testCancelledFetchAndMissingVersionDoNotCallBack() throws {
        let fixture = CovFMiscVersionFixture(version: "1.0.0")
        var calls = 0
        fixture.observer.checkVersion(from: nil) { _, _ in calls += 1 }
        let target = try XCTUnwrap(fixture.manager.enqueued.first as? BaseOperation<AppSupportConfig?>)
        target.completionBlock?()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(calls, 0)

        let unknown = CovFMiscVersionFixture(version: nil)
        unknown.observer.checkVersion(from: nil) { _, _ in calls += 1 }
        XCTAssertTrue(unknown.manager.enqueued.isEmpty)
        XCTAssertEqual(calls, 0)
    }
}

private final class CovFMiscVersionFixture {
    let manager = CovFMiscCapturingManager()
    let wireframe = CovFMiscVersionWireframe()
    let observer: AppVersionObserver

    init(version: String?) {
        observer = AppVersionObserver(operationManager: manager, currentAppVersion: version, wireframe: wireframe,
                                      locale: Locale(identifier: "en"))
    }

    func config(min: String, excluded: [String]) throws -> AppSupportConfig {
        let json: [String: Any] = [
            AppSupportConfig.CodingKeys.minSupportedVersion.stringValue: min,
            AppSupportConfig.CodingKeys.excludedVersions.stringValue: excluded
        ]
        return try JSONDecoder().decode(AppSupportConfig.self, from: JSONSerialization.data(withJSONObject: json))
    }

    func check(config: Result<AppSupportConfig?, Error>) throws -> (supported: Bool?, error: Error?) {
        let done = XCTestExpectation(description: "version checked")
        var outcome: (Bool?, Error?) = (nil, nil)
        observer.checkVersion(from: nil) { supported, error in
            outcome = (supported, error)
            done.fulfill()
        }
        let target = try XCTUnwrap(manager.enqueued.first as? BaseOperation<AppSupportConfig?>)
        target.result = config
        target.completionBlock?()
        XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: 5), .completed)
        return outcome
    }
}

private final class CovFMiscCapturingManager: OperationManagerProtocol {
    var enqueued: [Operation] = []
    func enqueue(operations: [Operation], in _: OperationMode) { enqueued.append(contentsOf: operations) }
}

private final class CovFMiscVersionWireframe: WarningPresentable, AppUpdatePresentable, PresentDismissable {
    var warnings: [WarningAlertConfig] = []
    var handlers: [WarningAlertButtonHandler] = []
    var storeOpens = 0
    var dismissed = 0

    func presentWarningAlert(from _: ControllerBackedProtocol?, config: WarningAlertConfig, buttonHandler: @escaping WarningAlertButtonHandler) {
        warnings.append(config)
        handlers.append(buttonHandler)
    }

    func showAppstoreUpdatePage() { storeOpens += 1 }
    func dismiss(view _: ControllerBackedProtocol?) { dismissed += 1 }
}
