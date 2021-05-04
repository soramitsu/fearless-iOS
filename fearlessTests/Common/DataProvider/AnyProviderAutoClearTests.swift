import XCTest
@testable import fearless
import RobinHood

class AnyProviderAutoClearTests: XCTestCase {

    func testPerformanceExample() throws {
        // given

        let cleaner = AnyProviderAutoCleaner()
        let singleValueProvider = SingleValueProviderFactoryStub.westendNominatorStub()

        let runtimeService = try RuntimeCodingServiceStub.createWestendService()

        var provider: AnyDataProvider<DecodedElectionStatus>? =
            try singleValueProvider.getElectionStatusProvider(
            chain: .westend,
            runtimeService: runtimeService
        )

        // when

        XCTAssertNotNil(provider)

        cleaner.clear(dataProvider: &provider)

        XCTAssertNil(provider)
    }

}
