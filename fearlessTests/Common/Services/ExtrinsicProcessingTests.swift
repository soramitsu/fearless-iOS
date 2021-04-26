import XCTest
@testable import fearless
import IrohaCrypto

class ExtrinsicProcessingTests: XCTestCase {
    let transferExtrinsicHex = "0x3d0284003c3cfe3aac7a376cc859c6add617adce002fe598ac3add7ba7319b7072316b03017ed10d4c19c84c485b3af73154fef2bae6f9d7360a76296bb00a751330e098363171662252df788dd21310e9161c43b24d141da85ac7805ce5bd67f997c2b9890024000400004c094920ae177d5bd42f54b0a22f69b05f7e1c3abacaa021e63626470ae8d90c0700e40b5402"

    let extrinsicIndex: UInt32 = 1

    let eventRecordsHex = "0x100000000000000070f0020b00000000020000000100000004023c3cfe3aac7a376cc859c6add617adce002fe598ac3add7ba7319b7072316b034c094920ae177d5bd42f54b0a22f69b05f7e1c3abacaa021e63626470ae8d90c00e40b540200000000000000000000000000010000000404aebb0211dbb07b4d335a657257b8ac5e53794c901e4f616d4a254f2490c439344c41df9b0300000000000000000000000000010000000000d039030c00000000000000"

    let transferSender = "5DRgrCCSuBFqbXMj6fSiZVBDEaDDcQCa4zXBKftPoRAGjb72"
    let transferReceiver = "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq"
    let chain = Chain.westend

    func testTransferSuccessfullProcessing() {
        do {
            let addressFactory = SS58AddressFactory()
            let senderAccountId = try addressFactory.accountId(from: transferSender)
            let receiverAccountId = try addressFactory.accountId(from: transferReceiver)

            let coderFactory = try RuntimeCodingServiceStub.createWestendCodingFactory()
            let processor = ExtrinsicProcessor(accountId: senderAccountId)

            let eventRecordsData = try Data(hexString: eventRecordsHex)
            let typeName = coderFactory.metadata.getStorageMetadata(for: .events)!.type.typeName
            let decoder = try coderFactory.createDecoder(from: eventRecordsData)
            let eventRecords: [EventRecord] = try decoder.read(of: typeName)

            let extrinsicData = try Data(hexString: transferExtrinsicHex)

            guard let result = processor.process(
                    extrinsicIndex: extrinsicIndex,
                    extrinsicData: extrinsicData,
                    eventRecords: eventRecords,
                    coderFactory: coderFactory
            ) else {
                XCTFail("Unexpected empty result")
                return
            }

            XCTAssertEqual(.transfer, result.callPath)
            XCTAssertTrue(result.isSuccess)

            guard let fee = result.fee else {
                XCTFail("Missing fee")
                return
            }

            XCTAssertTrue(fee > 0)

            XCTAssertEqual(receiverAccountId, result.peerId)

        } catch {
            XCTFail("Did receiver error: \(error)")
        }
    }
}
