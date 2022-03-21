import XCTest
@testable import fearless

class AppVersionObserverTests: XCTestCase {
    
    private var minSupportedVersion: String = "2.0.6"
    private var excludedVersions: [String] = ["2.0.3", "2.0.7"]

    private var testData: [String: Any?] {
        return ["min_supported_version" : minSupportedVersion,
                "excluded_versions" : excludedVersions]
    }
    
    func testAppVersionURL() {
        XCTAssertNotNil(ApplicationConfig.shared.appVersionURL)
    }
    
    func testCurrentVersion() {
        XCTAssertNotNil(AppVersion.stringValue)
    }
    
    func createObserverForVersion(_ version: String) throws -> AppVersionObserverProtocol {
        guard let url = ApplicationConfig.shared.appVersionURL else {
            throw AppVersionError.appVersionUrlBroken
        }
        
        let jsonDataProviderFactory = JsonDataProviderFactoryStub(sources: [url: testData])
        
        let versionLowerThanRequired = version

        return AppVersionObserver(jsonLocalSubscriptionFactory: jsonDataProviderFactory,
                                  currentAppVersion: versionLowerThanRequired)
    }
    
    func testLowVersion() {
        let versionLowerThanRequired = "2.0.2"

        do {
            let appVersionObserver: AppVersionObserverProtocol = try createObserverForVersion(versionLowerThanRequired)
            
            let expectation = XCTestExpectation()
            expectation.expectedFulfillmentCount = 1
            
            appVersionObserver.checkVersion { suppored, error in
                XCTAssertEqual(suppored, false)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testExcludedVersion() {
        guard let excludedVersion = excludedVersions.first else {
            XCTFail("Missed excluded version for test")
            return
        }
        
        do {
            let appVersionObserver: AppVersionObserverProtocol = try createObserverForVersion(excludedVersion)
            
            let expectation = XCTestExpectation()
            expectation.expectedFulfillmentCount = 1
            
            appVersionObserver.checkVersion { suppored, error in
                XCTAssertEqual(suppored, false)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSupportedVersion() {
        do {
            let appVersionObserver: AppVersionObserverProtocol = try createObserverForVersion("2.0.8")
            
            let expectation = XCTestExpectation()
            expectation.expectedFulfillmentCount = 1
            
            appVersionObserver.checkVersion { suppored, error in
                XCTAssertEqual(suppored, false)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
