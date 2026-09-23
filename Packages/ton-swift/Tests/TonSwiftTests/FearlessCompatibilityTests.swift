import XCTest
@testable import TonSwift

final class FearlessCompatibilityTests: XCTestCase {
    func test_library_matchesIndependentTonCore() throws {
        let boc = Data(base64Encoded: "te6cckEBAQEAIwAIQgJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQvb5cRU=")!
        let cell = try XCTUnwrap(Cell.fromBoc(src: boc).first)
        XCTAssertEqual(cell.hash(level: 0).hexString(), "099af5203b3229b13bbdf0ed6f4bbf597c3d029baa1dd552ed420e77c354b1ab")
        XCTAssertEqual(cell.depth(level: 0), 0)
        XCTAssertEqual(cell.hash(level: 1).hexString(), "099af5203b3229b13bbdf0ed6f4bbf597c3d029baa1dd552ed420e77c354b1ab")
        XCTAssertEqual(cell.depth(level: 1), 0)
        XCTAssertEqual(cell.hash(level: 2).hexString(), "099af5203b3229b13bbdf0ed6f4bbf597c3d029baa1dd552ed420e77c354b1ab")
        XCTAssertEqual(cell.depth(level: 2), 0)
        XCTAssertEqual(cell.hash(level: 3).hexString(), "099af5203b3229b13bbdf0ed6f4bbf597c3d029baa1dd552ed420e77c354b1ab")
        XCTAssertEqual(cell.depth(level: 3), 0)
        XCTAssertEqual(try Cell.fromBoc(src: cell.toBoc()).first, cell)
    }
    func test_libraryStateInit_matchesIndependentTonCore() throws {
        let boc = Data(base64Encoded: "te6cckEBAwEALgACATQBAghCAkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCAAgAAAATG6x6GQ==")!
        let cell = try XCTUnwrap(Cell.fromBoc(src: boc).first)
        XCTAssertEqual(cell.hash(level: 0).hexString(), "88bbe439f5a9b598daaf3d183a71b857d6b84fb0614681317012fc1960b5ff8e")
        XCTAssertEqual(cell.depth(level: 0), 1)
        XCTAssertEqual(cell.hash(level: 1).hexString(), "88bbe439f5a9b598daaf3d183a71b857d6b84fb0614681317012fc1960b5ff8e")
        XCTAssertEqual(cell.depth(level: 1), 1)
        XCTAssertEqual(cell.hash(level: 2).hexString(), "88bbe439f5a9b598daaf3d183a71b857d6b84fb0614681317012fc1960b5ff8e")
        XCTAssertEqual(cell.depth(level: 2), 1)
        XCTAssertEqual(cell.hash(level: 3).hexString(), "88bbe439f5a9b598daaf3d183a71b857d6b84fb0614681317012fc1960b5ff8e")
        XCTAssertEqual(cell.depth(level: 3), 1)
        XCTAssertEqual(try Cell.fromBoc(src: cell.toBoc()).first, cell)
    }
    func test_pruned1_matchesIndependentTonCore() throws {
        let boc = Data(base64Encoded: "te6cckEBAQEAJgAoSAEBEREREREREREREREREREREREREREREREREREREREREREAAeg9pko=")!
        let cell = try XCTUnwrap(Cell.fromBoc(src: boc).first)
        XCTAssertEqual(cell.hash(level: 0).hexString(), "1111111111111111111111111111111111111111111111111111111111111111")
        XCTAssertEqual(cell.depth(level: 0), 1)
        XCTAssertEqual(cell.hash(level: 1).hexString(), "6539f5f6ad7758f970b0e8b5b51919845089ac2dd34138fe40e684d26b9044e6")
        XCTAssertEqual(cell.depth(level: 1), 0)
        XCTAssertEqual(cell.hash(level: 2).hexString(), "6539f5f6ad7758f970b0e8b5b51919845089ac2dd34138fe40e684d26b9044e6")
        XCTAssertEqual(cell.depth(level: 2), 0)
        XCTAssertEqual(cell.hash(level: 3).hexString(), "6539f5f6ad7758f970b0e8b5b51919845089ac2dd34138fe40e684d26b9044e6")
        XCTAssertEqual(cell.depth(level: 3), 0)
        XCTAssertEqual(try Cell.fromBoc(src: cell.toBoc()).first, cell)
    }
    func test_pruned3_matchesIndependentTonCore() throws {
        let boc = Data(base64Encoded: "te6cckEBAQEASABojAEDERERERERERERERERERERERERERERERERERERERERERESEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEgABAAJ2nvaJ")!
        let cell = try XCTUnwrap(Cell.fromBoc(src: boc).first)
        XCTAssertEqual(cell.hash(level: 0).hexString(), "1111111111111111111111111111111111111111111111111111111111111111")
        XCTAssertEqual(cell.depth(level: 0), 1)
        XCTAssertEqual(cell.hash(level: 1).hexString(), "1212121212121212121212121212121212121212121212121212121212121212")
        XCTAssertEqual(cell.depth(level: 1), 2)
        XCTAssertEqual(cell.hash(level: 2).hexString(), "7ee2bbd542232c6559b55ad2feb6a5f5b86b34dc17586c0667668e50ecdc8c98")
        XCTAssertEqual(cell.depth(level: 2), 0)
        XCTAssertEqual(cell.hash(level: 3).hexString(), "7ee2bbd542232c6559b55ad2feb6a5f5b86b34dc17586c0667668e50ecdc8c98")
        XCTAssertEqual(cell.depth(level: 3), 0)
        XCTAssertEqual(try Cell.fromBoc(src: cell.toBoc()).first, cell)
    }
    func test_pruned7_matchesIndependentTonCore() throws {
        let boc = Data(base64Encoded: "te6cckEBAQEAagDo0AEHERERERERERERERERERERERERERERERERERERERERERESEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhMTExMTExMTExMTExMTExMTExMTExMTExMTExMTExMTAAEAAgADGWyNBg==")!
        let cell = try XCTUnwrap(Cell.fromBoc(src: boc).first)
        XCTAssertEqual(cell.hash(level: 0).hexString(), "1111111111111111111111111111111111111111111111111111111111111111")
        XCTAssertEqual(cell.depth(level: 0), 1)
        XCTAssertEqual(cell.hash(level: 1).hexString(), "1212121212121212121212121212121212121212121212121212121212121212")
        XCTAssertEqual(cell.depth(level: 1), 2)
        XCTAssertEqual(cell.hash(level: 2).hexString(), "1313131313131313131313131313131313131313131313131313131313131313")
        XCTAssertEqual(cell.depth(level: 2), 3)
        XCTAssertEqual(cell.hash(level: 3).hexString(), "f0dca87f3f068769cf622e9984be868a993681d5981fb708c577de6cc6ab201d")
        XCTAssertEqual(cell.depth(level: 3), 0)
        XCTAssertEqual(try Cell.fromBoc(src: cell.toBoc()).first, cell)
    }
    func test_proof_matchesIndependentTonCore() throws {
        let boc = Data(base64Encoded: "te6cckEBAgEALAAJRgOWN09dJpMHnqld5gjNzJuE7HhfuasRqdH6dFZq1oEaogAAAQAIAAAE0omiECY=")!
        let cell = try XCTUnwrap(Cell.fromBoc(src: boc).first)
        XCTAssertEqual(cell.hash(level: 0).hexString(), "962e4f5ebfcf28e6d8e934ae70ff7d94150d6d183a774300021d2a3765da0b53")
        XCTAssertEqual(cell.depth(level: 0), 1)
        XCTAssertEqual(cell.hash(level: 1).hexString(), "962e4f5ebfcf28e6d8e934ae70ff7d94150d6d183a774300021d2a3765da0b53")
        XCTAssertEqual(cell.depth(level: 1), 1)
        XCTAssertEqual(cell.hash(level: 2).hexString(), "962e4f5ebfcf28e6d8e934ae70ff7d94150d6d183a774300021d2a3765da0b53")
        XCTAssertEqual(cell.depth(level: 2), 1)
        XCTAssertEqual(cell.hash(level: 3).hexString(), "962e4f5ebfcf28e6d8e934ae70ff7d94150d6d183a774300021d2a3765da0b53")
        XCTAssertEqual(cell.depth(level: 3), 1)
        XCTAssertEqual(try Cell.fromBoc(src: cell.toBoc()).first, cell)
    }
    func test_update_matchesIndependentTonCore() throws {
        let boc = Data(base64Encoded: "te6cckEBAwEAcgAKigSWN09dJpMHnqld5gjNzJuE7HhfuasRqdH6dFZq1oEaogma9SA7MimxO73w7W9Lv1l8PQKbqh3VUu1CDnfDVLGrAAAAAAECAAgAAATSCEICQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkIEsgC0")!
        let cell = try XCTUnwrap(Cell.fromBoc(src: boc).first)
        XCTAssertEqual(cell.hash(level: 0).hexString(), "e9cf7ba69dcae4a20ee8bea92dc5b853cec4fa0372e463c015c6516f198f6f88")
        XCTAssertEqual(cell.depth(level: 0), 1)
        XCTAssertEqual(cell.hash(level: 1).hexString(), "e9cf7ba69dcae4a20ee8bea92dc5b853cec4fa0372e463c015c6516f198f6f88")
        XCTAssertEqual(cell.depth(level: 1), 1)
        XCTAssertEqual(cell.hash(level: 2).hexString(), "e9cf7ba69dcae4a20ee8bea92dc5b853cec4fa0372e463c015c6516f198f6f88")
        XCTAssertEqual(cell.depth(level: 2), 1)
        XCTAssertEqual(cell.hash(level: 3).hexString(), "e9cf7ba69dcae4a20ee8bea92dc5b853cec4fa0372e463c015c6516f198f6f88")
        XCTAssertEqual(cell.depth(level: 3), 1)
        XCTAssertEqual(try Cell.fromBoc(src: cell.toBoc()).first, cell)
    }
    func test_ordinaryWithPruned_matchesIndependentTonCore() throws {
        let boc = Data(base64Encoded: "te6cckEBAgEATABhAgkBaIwBAxEREREREREREREREREREREREREREREREREREREREREREhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhIAAQACaJ6B+A==")!
        let cell = try XCTUnwrap(Cell.fromBoc(src: boc).first)
        XCTAssertEqual(cell.hash(level: 0).hexString(), "3f14b7ba27aa10a76e9756fd768203efe7c66169435ea4698c14040069a18e76")
        XCTAssertEqual(cell.depth(level: 0), 2)
        XCTAssertEqual(cell.hash(level: 1).hexString(), "fda109e972132c761fa940a86107e29bbc86967fc4f2928e4815a3dd4c0f9eb2")
        XCTAssertEqual(cell.depth(level: 1), 3)
        XCTAssertEqual(cell.hash(level: 2).hexString(), "0dde37cf96f4f6dc7ec8109a0a9ad36ce338075f165c004ff91053d84c9019b2")
        XCTAssertEqual(cell.depth(level: 2), 1)
        XCTAssertEqual(cell.hash(level: 3).hexString(), "0dde37cf96f4f6dc7ec8109a0a9ad36ce338075f165c004ff91053d84c9019b2")
        XCTAssertEqual(cell.depth(level: 3), 1)
        XCTAssertEqual(try Cell.fromBoc(src: cell.toBoc()).first, cell)
    }
    func testLibraryRejectsInvalidShape() throws {
        XCTAssertThrowsError(try Cell(exotic: true, bits: Bitstring(data: Data([2]))))
        XCTAssertThrowsError(try Cell(exotic: true, bits: Bitstring(data: Data([2]) + Data(repeating: 0, count: 32)), refs: [try Cell(data: Data())]))
    }
    func testMalformedBocIndicesThrow() throws {
        var root = Data([0xb5,0xee,0x9c,0x72,1,1,1,1,0,2,1,0,0])
        XCTAssertThrowsError(try Cell.fromBoc(src: root))
        root[10] = 0
        XCTAssertNoThrow(try Cell.fromBoc(src: root))
        let badRef = Data([0xb5,0xee,0x9c,0x72,1,1,1,1,0,3,0,1,0,99])
        XCTAssertThrowsError(try Cell.fromBoc(src: badRef))
    }
}
