import XCTest
@testable import fearless

/// CustomCrowdloanFlow's hand-written == had no `.unsupported` case, so an unsupported flow (any name the app does not
/// know) was not equal to itself, and neither was a CrowdloanDisplayInfo carrying one. Nothing compares them today.
final class CustomCrowdloanFlowEqualityTests: XCTestCase {
    func testUnsupportedFlowsCompareByName() {
        XCTAssertEqual(CustomCrowdloanFlow.unsupported("polkadex"), .unsupported("polkadex"))
        XCTAssertNotEqual(CustomCrowdloanFlow.unsupported("polkadex"), .unsupported("other"))
        XCTAssertNotEqual(CustomCrowdloanFlow.unsupported("karura"), .karura)
    }

    func testDisplayInfoWithAnUnsupportedFlowEqualsItself() {
        let info = CrowdloanDisplayInfo(
            paraid: "2000", name: "Polkadex", token: "PDEX", description: "", website: "", icon: "",
            rewardRate: nil, endingBlock: nil, disabled: nil, flow: .unsupported("polkadex")
        )

        XCTAssertEqual(info, info)
    }
}
