import XCTest

/// Launches the real app (live engine) against a throwaway wallet store.
final class FearlessMacLaunchTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FEARLESS_STORAGE_PROFILE"] = "uitest-" + UUID().uuidString.prefix(8)
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testFirstLaunchShowsOnboardingWindow() throws {
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 30), "main window did not appear")
        XCTAssertGreaterThan(app.windows.firstMatch.frame.width, 800)
    }
}
