import XCTest
@testable import fearless

class CountdownTests: XCTestCase, RuntimeConstantFetching {

    func testNumberOfSessionsPerEra() {
        let runtimeCodingService = try! RuntimeCodingServiceStub.createWestendService()
        let operationManager = OperationManagerFacade.sharedManager

        let sessionExpectation = XCTestExpectation()
        fetchConstant(
            for: .eraLength,
            runtimeCodingService: runtimeCodingService,
            operationManager: operationManager
        ) { (result: Result<UInt32, Error>) in
            switch result {
            case let .success(index):
                if index == 6 {
                    sessionExpectation.fulfill()
                } else {
                    XCTFail("""
                        SessionsPerEra for westend has been changed.
                        See https://github.com/paritytech/polkadot/blob/956d6ae183a0b7f662d37bbbd251b64423f9701c/runtime/westend/src/lib.rs#L418
                    """)
                }
            case let .failure(error):
                XCTFail(error.localizedDescription)
            }
        }

        wait(for: [sessionExpectation], timeout: 10)
    }
}
