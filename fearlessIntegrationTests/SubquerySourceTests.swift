import Foundation
import XCTest
@testable import fearless

class SubquerySourceTests: XCTestCase {

    func testTransfers() {
        let source = SubqueryTransfersSource(
            address: "15cfSaBcTxNr8rV59cbhdMNCRagFr3GE6B3zZRsCp4QHHKPu",
            url: URL(string: "http://localhost:3000/")!,
            chain: .polkadot
        )
        let operation = source.fetchOperation()
        OperationQueue().addOperations(operation.allOperations, waitUntilFinished: true)
        do {
            let transfers = try operation.targetOperation.extractNoCancellableResultData() ?? []
            XCTAssert(!transfers.isEmpty)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
