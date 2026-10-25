import XCTest
@testable import TonSwift

final class CommonMessageInfoTest: XCTestCase {
    
    func testCommonMessageInfo() throws {
        // should serialize external-in messages
        let msg1 = CommonMsgInfo.externalInInfo(
            info: .init(
                src: try ExternalAddress.mock(seed: "src"),
                dest: Address.mock(workchain: 0, seed: "dest"),
                importFee: Coins(0)
            )
        )
        
        let cell1 = try Builder().store(msg1).endCell()
        let msg2: CommonMsgInfo = try cell1.beginParse().loadType()
        let cell2 = try Builder().store(msg2).endCell()
        XCTAssertEqual(cell1, cell2)
    }
}
