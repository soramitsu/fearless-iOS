//import XCTest
//@testable import fearless
//import IrohaCrypto
//
//class ExtrinsicProcessingTests: XCTestCase {
//    let transferExtrinsicHex = "0x0400009e310f2ca374690de940e430aa47ebbea5cafff2c6d7223b95cfacb21ce0bf5c0700e87648172500ad01000e2400000b000000e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423ecefefb0824b8d7a30857a992ed23bfeb85d4975396254044014d314d99fa24d1"
//
//    let extrinsicIndex: UInt32 = 1
//
//    let eventRecordsHex = "0x100000000000000070f0020b00000000020000000100000004023c3cfe3aac7a376cc859c6add617adce002fe598ac3add7ba7319b7072316b034c094920ae177d5bd42f54b0a22f69b05f7e1c3abacaa021e63626470ae8d90c00e40b540200000000000000000000000000010000000404aebb0211dbb07b4d335a657257b8ac5e53794c901e4f616d4a254f2490c439344c41df9b0300000000000000000000000000010000000000d039030c00000000000000"
//
//    let transferSender = "5DRgrCCSuBFqbXMj6fSiZVBDEaDDcQCa4zXBKftPoRAGjb72"
//    let transferReceiver = "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq"
//
//    func testTransferSuccessfullProcessing() {
//        do {
//            let addressFactory = SS58AddressFactory()
//            let senderAccountId = try addressFactory.accountId(from: transferSender)
//            let receiverAccountId = try addressFactory.accountId(from: transferReceiver)
//
//            let coderFactory = try RuntimeCodingServiceStub.createWestendCodingFactory(metadataVersion: 14)
//            let processor = ExtrinsicProcessor(accountId: senderAccountId)
//
//            let eventRecordsData = try Data(hexStringSSF: eventRecordsHex)
//            let type = coderFactory.metadata.getStorageMetadata(for: .events)!.type
//            let resolver = coderFactory.metadata.schemaResolver
//            let typeName = try type.typeName(using: resolver)
//            let decoder = try coderFactory.createDecoder(from: eventRecordsData)
//            let eventRecords: [EventRecord] = try decoder.read(of: typeName)
//
//            let extrinsicData = try Data(hexStringSSF: transferExtrinsicHex)
//
//            guard let result = processor.process(
//                    extrinsicIndex: extrinsicIndex,
//                    extrinsicData: extrinsicData,
//                    eventRecords: eventRecords,
//                    coderFactory: coderFactory
//            ) else {
//                XCTFail("Unexpected empty result")
//                return
//            }
//
//            XCTAssertEqual(.transfer, result.callPath)
//            XCTAssertTrue(result.isSuccess)
//
//            guard let fee = result.fee else {
//                XCTFail("Missing fee")
//                return
//            }
//
//            XCTAssertTrue(fee > 0)
//
//            XCTAssertEqual(receiverAccountId, result.peerId)
//
//        } catch {
//            XCTFail("Did receiver error: \(error)")
//        }
//    }
//}
