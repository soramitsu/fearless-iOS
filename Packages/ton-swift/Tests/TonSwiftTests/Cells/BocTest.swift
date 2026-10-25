import XCTest
@testable import TonSwift

final class SerializationTest: XCTestCase {
    
    private let wallets = [
        "B5EE9C72410101010044000084FF0020DDA4F260810200D71820D70B1FED44D0D31FD3FFD15112BAF2A122F901541044F910F2A2F80001D31F3120D74A96D307D402FB00DED1A4C8CB1FCBFFC9ED5441FDF089",
        "B5EE9C724101010100530000A2FF0020DD2082014C97BA9730ED44D0D70B1FE0A4F260810200D71820D70B1FED44D0D31FD3FFD15112BAF2A122F901541044F910F2A2F80001D31F3120D74A96D307D402FB00DED1A4C8CB1FCBFFC9ED54D0E2786F",
        "B5EE9C7241010101005F0000BAFF0020DD2082014C97BA218201339CBAB19C71B0ED44D0D31FD70BFFE304E0A4F260810200D71820D70B1FED44D0D31FD3FFD15112BAF2A122F901541044F910F2A2F80001D31F3120D74A96D307D402FB00DED1A4C8CB1FCBFFC9ED54B5B86E42",
        "B5EE9C724101010100570000AAFF0020DD2082014C97BA9730ED44D0D70B1FE0A4F2608308D71820D31FD31F01F823BBF263ED44D0D31FD3FFD15131BAF2A103F901541042F910F2A2F800029320D74A96D307D402FB00E8D1A4C8CB1FCBFFC9ED54A1370BB6",
        "B5EE9C724101010100630000C2FF0020DD2082014C97BA218201339CBAB19C71B0ED44D0D31FD70BFFE304E0A4F2608308D71820D31FD31F01F823BBF263ED44D0D31FD3FFD15131BAF2A103F901541042F910F2A2F800029320D74A96D307D402FB00E8D1A4C8CB1FCBFFC9ED54044CD7A1",
        "B5EE9C724101010100620000C0FF0020DD2082014C97BA9730ED44D0D70B1FE0A4F2608308D71820D31FD31FD31FF82313BBF263ED44D0D31FD31FD3FFD15132BAF2A15144BAF2A204F901541055F910F2A3F8009320D74A96D307D402FB00E8D101A4C8CB1FCB1FCBFFC9ED543FBE6EE0",
        "B5EE9C724101010100710000DEFF0020DD2082014C97BA218201339CBAB19F71B0ED44D0D31FD31F31D70BFFE304E0A4F2608308D71820D31FD31FD31FF82313BBF263ED44D0D31FD31FD3FFD15132BAF2A15144BAF2A204F901541055F910F2A3F8009320D74A96D307D402FB00E8D101A4C8CB1FCB1FCBFFC9ED5410BD6DAD"
    ];
    
    func testSerialization() throws {
        // should parse wallet code
        for w in wallets {
            let c = try deserializeBoc(src: Data(hex: w)!)[0]
            let b = try serializeBoc(root: c, idx: false, crc32: true)
            let c2 = try deserializeBoc(src: b)[0]
            XCTAssertEqual(c, c2)
        }
        
        // TODO: create tests for large and files
        
        // should serialize single cell with a empty bits
        var cell = try Builder().endCell()
        XCTAssertEqual(try cell.toString(), "x{}")
        XCTAssertEqual(cell.hash().base64EncodedString(), "lqKW0iTyhcZ77pPDD4owkVfw2qNdxbh+QQt4YwoJz8c=")
        XCTAssertEqual(try serializeBoc(root: cell, idx: false, crc32: false).base64EncodedString(), "te6ccgEBAQEAAgAAAA==")
        XCTAssertEqual(try serializeBoc(root: cell, idx: false, crc32: true).base64EncodedString(), "te6cckEBAQEAAgAAAEysuc0=")
        XCTAssertEqual(try serializeBoc(root: cell, idx: true, crc32: false).base64EncodedString(), "te6ccoEBAQEAAgAAAAA=")
        XCTAssertEqual(try serializeBoc(root: cell, idx: true, crc32: true).base64EncodedString(), "te6ccsEBAQEAAgAAAAC1U5ck")
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccgEBAQEAAgAAAA==")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6cckEBAQEAAgAAAEysuc0=")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccoEBAQEAAgAAAAA=")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccsEBAQEAAgAAAAC1U5ck")!)[0], cell)
        
        // should serialize single cell with a number of byte-aligned bits
        cell = try Builder().store(uint: UInt64(123456789), bits: 32).endCell()
        XCTAssertEqual(try cell.toString(), "x{075BCD15}")
        XCTAssertEqual(cell.hash().base64EncodedString(), "keNT38owvINaYYHwYjE1R8HYk0c1NSMH72u+/aMJ+1c=")
        XCTAssertEqual(try serializeBoc(root: cell, idx: false, crc32: false).base64EncodedString(), "te6ccgEBAQEABgAACAdbzRU=")
        XCTAssertEqual(try serializeBoc(root: cell, idx: false, crc32: true).base64EncodedString(), "te6cckEBAQEABgAACAdbzRVRblCS")
        XCTAssertEqual(try serializeBoc(root: cell, idx: true, crc32: false).base64EncodedString(), "te6ccoEBAQEABgAAAAgHW80V")
        XCTAssertEqual(try serializeBoc(root: cell, idx: true, crc32: true).base64EncodedString(), "te6ccsEBAQEABgAAAAgHW80Vyf0TAA==")
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccgEBAQEABgAACAdbzRU=")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6cckEBAQEABgAACAdbzRVRblCS")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccoEBAQEABgAAAAgHW80V")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccsEBAQEABgAAAAgHW80Vyf0TAA==")!)[0], cell)
        
        // should serialize single cell with a number of non-aligned bits
        cell = try Builder().store(uint: UInt64(123456789), bits: 34).endCell()
        XCTAssertEqual(try cell.toString(), "x{01D6F3456_}")
        XCTAssertEqual(cell.hash().base64EncodedString(), "Rk+nt8kkAyN9S1v4H0zwFbGs2INwpMHvESvPQbrI6d0=")
        XCTAssertEqual(try serializeBoc(root: cell, idx: false, crc32: false).base64EncodedString(), "te6ccgEBAQEABwAACQHW80Vg")
        XCTAssertEqual(try serializeBoc(root: cell, idx: false, crc32: true).base64EncodedString(), "te6cckEBAQEABwAACQHW80Vgb11ZoQ==")
        XCTAssertEqual(try serializeBoc(root: cell, idx: true, crc32: false).base64EncodedString(), "te6ccoEBAQEABwAAAAkB1vNFYA==")
        XCTAssertEqual(try serializeBoc(root: cell, idx: true, crc32: true).base64EncodedString(), "te6ccsEBAQEABwAAAAkB1vNFYMkX0oY=")
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccgEBAQEABwAACQHW80Vg")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6cckEBAQEABwAACQHW80Vgb11ZoQ==")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccoEBAQEABwAAAAkB1vNFYA==")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccsEBAQEABwAAAAkB1vNFYMkX0oY=")!)[0], cell)

        // should serialize single cell with a single reference
        var refCell = try Builder()
            .store(uint: UInt64(123456789), bits: 32)
            .endCell()
        cell = try Builder()
            .store(uint: UInt64(987654321), bits: 32)
            .store(ref: refCell)
            .endCell()
        XCTAssertEqual(try cell.toString(), "x{3ADE68B1}\n x{075BCD15}")
        XCTAssertEqual(cell.hash().base64EncodedString(), "goaQYcsXO2c/gd3qvMo3ncEjzpbU7urNQ7hPDo0qC1c=")
        XCTAssertEqual(try serializeBoc(root: cell, idx: false, crc32: false).base64EncodedString(), "te6ccgEBAgEADQABCDreaLEBAAgHW80V")
        XCTAssertEqual(try serializeBoc(root: cell, idx: false, crc32: true).base64EncodedString(), "te6cckEBAgEADQABCDreaLEBAAgHW80VSW/75w==")
        XCTAssertEqual(try serializeBoc(root: cell, idx: true, crc32: false).base64EncodedString(), "te6ccoEBAgEADQAABwEIOt5osQEACAdbzRU=")
        XCTAssertEqual(try serializeBoc(root: cell, idx: true, crc32: true).base64EncodedString(), "te6ccsEBAgEADQAABwEIOt5osQEACAdbzRWZVy8t")
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccgEBAgEADQABCDreaLEBAAgHW80V")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6cckEBAgEADQABCDreaLEBAAgHW80VSW/75w==")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccoEBAgEADQAABwEIOt5osQEACAdbzRU=")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccsEBAgEADQAABwEIOt5osQEACAdbzRWZVy8t")!)[0], cell)
        
        // should serialize single cell with multiple references
        refCell = try Builder()
            .store(uint: UInt64(123456789), bits: 32)
            .endCell()
        cell = try Builder()
            .store(uint: UInt64(987654321), bits: 32)
            .store(ref: refCell)
            .store(ref: refCell)
            .store(ref: refCell)
            .endCell()
        XCTAssertEqual(try cell.toString(), "x{3ADE68B1}\n x{075BCD15}\n x{075BCD15}\n x{075BCD15}")
        XCTAssertEqual(cell.hash().base64EncodedString(), "cks0wbfqFZE9/yb0sWMWQGoj0XBOLkUi+aX5xpJ6jjA=")
        XCTAssertEqual(try serializeBoc(root: cell, idx: false, crc32: false).base64EncodedString(), "te6ccgEBAgEADwADCDreaLEBAQEACAdbzRU=")
        XCTAssertEqual(try serializeBoc(root: cell, idx: false, crc32: true).base64EncodedString(), "te6cckEBAgEADwADCDreaLEBAQEACAdbzRWpQD2p")
        XCTAssertEqual(try serializeBoc(root: cell, idx: true, crc32: false).base64EncodedString(), "te6ccoEBAgEADwAACQMIOt5osQEBAQAIB1vNFQ==")
        XCTAssertEqual(try serializeBoc(root: cell, idx: true, crc32: true).base64EncodedString(), "te6ccsEBAgEADwAACQMIOt5osQEBAQAIB1vNFT/vUE4=")
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccgEBAgEADwADCDreaLEBAQEACAdbzRU=")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6cckEBAgEADwADCDreaLEBAQEACAdbzRWpQD2p")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccoEBAgEADwAACQMIOt5osQEBAQAIB1vNFQ==")!)[0], cell)
        XCTAssertEqual(try deserializeBoc(src: Data(base64Encoded: "te6ccsEBAgEADwAACQMIOt5osQEBAQAIB1vNFT/vUE4=")!)[0], cell)
    }

}
