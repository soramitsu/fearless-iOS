import XCTest

@testable import SSFUtils

/// Exact call bytes against the metadata of Polkadot Asset Hub (spec 2005000).
///
/// The expected hex was assembled by hand from the SCALE rules and checked with a separate
/// registry driven decoder over the same metadata (it consumes every byte and yields the arguments
/// below); none of it comes from the code under test.
final class CallEncodingByteVectorTests: XCTestCase {
    /// 01 02 03 ... 20
    private let account = Data(1 ... 32)
    private let otherAccount = Data(0xA1 ... 0xC0)
    private let accountHex = "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
    private let otherAccountHex = "a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0"

    /// Compact<u128> of 10^12, a five byte big integer.
    private let amountHex = "070010a5d4e8"
    private let amount = "1000000000000"

    private var runtime: FixtureRuntime!

    override func setUpWithError() throws {
        try super.setUpWithError()
        runtime = try FixtureRuntime(.polkadotAssetHub)
    }

    // MARK: - Balances

    func testTransferAllowDeathIsCallZero() throws {
        let call = JSON.call("Balances", "transfer_allow_death", [
            "dest": .variant("Id", .bytes(account)),
            "value": .stringValue(amount),
        ])

        // module 10, call 0, MultiAddress::Id, account, Compact value
        XCTAssertEqual(try runtime.encode(call: call).hex, "0a00" + "00" + accountHex + amountHex)
    }

    func testTransferKeepAliveIsCallThreeNotTwo() throws {
        let call = JSON.call("Balances", "transfer_keep_alive", [
            "dest": .variant("Id", .bytes(account)),
            "value": .stringValue(amount),
        ])

        // Index 2 is force_transfer on this chain; position 2 of the call list is not the index.
        XCTAssertEqual(try runtime.encode(call: call).hex, "0a03" + "00" + accountHex + amountHex)
    }

    func testTransferAllIsCallFourNotThree() throws {
        let call = JSON.call("Balances", "transfer_all", [
            "dest": .variant("Id", .bytes(account)),
            "keep_alive": .boolValue(true),
        ])

        // Index 3 is transfer_keep_alive: with the position as index this would move the whole
        // balance of the call into a keep-alive transfer of value zero.
        XCTAssertEqual(try runtime.encode(call: call).hex, "0a04" + "00" + accountHex + "01")
    }

    func testForceTransferAndBurnFollowTheirRuntimeIndexes() throws {
        let forceTransfer = JSON.call("Balances", "force_transfer", [
            "source": .variant("Id", .bytes(account)),
            "dest": .variant("Id", .bytes(otherAccount)),
            "value": .stringValue("7"),
        ])
        let burn = JSON.call("Balances", "burn", [
            "value": .stringValue(amount),
            "keep_alive": .boolValue(false),
        ])

        XCTAssertEqual(
            try runtime.encode(call: forceTransfer).hex,
            "0a02" + "00" + accountHex + "00" + otherAccountHex + "1c"
        )
        XCTAssertEqual(try runtime.encode(call: burn).hex, "0a0a" + amountHex + "00")
    }

    func testDecodingUsesTheRuntimeIndexToo() throws {
        let transferKeepAlive = try runtime.decode(
            call: Data(hex: "0a03" + "00" + accountHex + amountHex)
        )
        let transferAll = try runtime.decode(call: Data(hex: "0a04" + "00" + accountHex + "01"))

        let expectedKeepAlive = JSON.call("Balances", "transfer_keep_alive", [
            "dest": .variant("Id", .bytes(account)),
            "value": .stringValue(amount),
        ])
        let expectedAll = JSON.call("Balances", "transfer_all", [
            "dest": .variant("Id", .bytes(account)),
            "keep_alive": .boolValue(true),
        ])
        XCTAssertEqual(transferKeepAlive, expectedKeepAlive)
        XCTAssertEqual(transferAll, expectedAll)
    }

    func testDecodingACallIndexTheRuntimeDoesNotUseFails() throws {
        // Balances has no call 1 (removed) and none above 10.
        for index in ["01", "07", "0b", "ff"] {
            XCTAssertThrowsError(
                try runtime.decode(call: Data(hex: "0a" + index + "00" + accountHex + amountHex))
            ) { error in
                guard case GenericCallNodeError.unexpectedCallFunction = error else {
                    return XCTFail(
                        "Expected unexpectedCallFunction for call \(index), got \(error)"
                    )
                }
            }
        }
    }

    func testEncodedCallsRoundTrip() throws {
        let calls = [
            JSON.call("Balances", "transfer_allow_death", [
                "dest": .variant("Id", .bytes(account)),
                "value": .stringValue(amount),
            ]),
            JSON.call("Balances", "force_transfer", [
                "source": .variant("Id", .bytes(account)),
                "dest": .variant("Id", .bytes(otherAccount)),
                "value": .stringValue("7"),
            ]),
            JSON.call("Balances", "burn", [
                "value": .stringValue("0"),
                "keep_alive": .boolValue(true),
            ]),
        ]

        for call in calls {
            XCTAssertEqual(try runtime.decode(call: runtime.encode(call: call)), call)
        }
    }

    // MARK: - PolkadotXcm

    func testLimitedTeleportAssetsToTheRelayChain() throws {
        let call = limitedTeleportAssets(unit: { .variant($0) })
        // The decoder hands a variant without fields back with an empty struct as payload.
        let decoded = limitedTeleportAssets(unit: { .variant($0, .dictionaryValue([:])) })

        let expected = "1f09"
            + "03" + "01" + "00" // dest: V3, parents 1, Here
            + "03" + "00" + "01" + "01" + "00" +
            accountHex // beneficiary: V3, 0, X1, AccountId32, None
            + "03" + "04" + "00" + "0100" + "00" +
            amountHex // assets: V3, 1 asset, Concrete(1, Here), Fungible
            + "00000000" // fee_asset_item
            + "00" // weight_limit: Unlimited
        let encoded = try runtime.encode(call: call)

        XCTAssertEqual(encoded.hex, expected)
        XCTAssertEqual(try runtime.decode(call: encoded), decoded)
    }

    /// dest: V3 { parents: 1, interior: Here },
    /// beneficiary: V3 { parents: 0, interior: X1(AccountId32 { network: None, id }) },
    /// assets: V3 [ { id: Concrete { parents: 1, Here }, fun: Fungible(10^12) } ].
    private func limitedTeleportAssets(unit: (String) -> JSON) -> JSON {
        JSON.call("PolkadotXcm", "limited_teleport_assets", [
            "dest": .variant("V3", .dictionaryValue([
                "parents": .stringValue("1"),
                "interior": unit("Here"),
            ])),
            "beneficiary": .variant("V3", .dictionaryValue([
                "parents": .stringValue("0"),
                "interior": .variant("X1", .variant("AccountId32", .dictionaryValue([
                    "network": .null,
                    "id": .bytes(account),
                ]))),
            ])),
            "assets": .variant("V3", .arrayValue([
                .dictionaryValue([
                    "id": .variant("Concrete", .dictionaryValue([
                        "parents": .stringValue("1"),
                        "interior": unit("Here"),
                    ])),
                    "fun": .variant("Fungible", .stringValue(amount)),
                ]),
            ])),
            "fee_asset_item": .stringValue("0"),
            "weight_limit": unit("Unlimited"),
        ])
    }

    func testAnXcmVersionTheRuntimeDroppedFailsInsteadOfEncodingSomethingElse() throws {
        // Polkadot Asset Hub only accepts V3 and newer locations.
        let call = JSON.call("PolkadotXcm", "limited_teleport_assets", [
            "dest": .variant("V1", .dictionaryValue([
                "parents": .stringValue("1"),
                "interior": .variant("Here"),
            ])),
            "beneficiary": .variant("V3", .dictionaryValue([
                "parents": .stringValue("0"),
                "interior": .variant("Here"),
            ])),
            "assets": .variant("V3", .arrayValue([])),
            "fee_asset_item": .stringValue("0"),
            "weight_limit": .variant("Unlimited"),
        ])

        XCTAssertThrowsError(try runtime.encode(call: call))
    }
}
