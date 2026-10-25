import BigInt
import XCTest

@testable import SSFXCM

final class XcmVersionedMultiLocationTests: XCTestCase {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    func testV3HoldsASingleJunctionBare() throws {
        // arrange
        let multilocation = XcmVersionedMultiLocation.V3(.init(
            parents: 0,
            interior: .init(items: [.onlyChild])
        ))

        // act
        let json = try String(decoding: encoder.encode(multilocation), as: UTF8.self)

        // assert
        XCTAssertEqual(json, #"["V3",{"interior":["X1",["OnlyChild",null]],"parents":"0"}]"#)
    }

    func testV4AndV5HoldJunctionsInAnArray() throws {
        let location = XcmV1MultiLocation(parents: 0, interior: .init(items: [.onlyChild]))

        XCTAssertEqual(
            try String(
                decoding: encoder.encode(XcmVersionedMultiLocation.V4(location)),
                as: UTF8.self
            ),
            #"["V4",{"interior":["X1",[["OnlyChild",null]]],"parents":"0"}]"#
        )
        XCTAssertEqual(
            try String(
                decoding: encoder.encode(XcmVersionedMultiLocation.V5(location)),
                as: UTF8.self
            ),
            #"["V5",{"interior":["X1",[["OnlyChild",null]]],"parents":"0"}]"#
        )
    }

    func testHereInV5() throws {
        let here = XcmVersionedMultiLocation.V5(.init(parents: 1, interior: .init(items: [])))

        XCTAssertEqual(
            try String(decoding: encoder.encode(here), as: UTF8.self),
            #"["V5",{"interior":["Here",null],"parents":"1"}]"#
        )
    }
}
