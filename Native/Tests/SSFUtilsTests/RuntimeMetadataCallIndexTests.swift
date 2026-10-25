import RuntimeMetadataFixtures
import XCTest

@testable import SSFUtils

/// A pallet's call enum does not number its calls 0, 1, 2, ...: calls that were removed leave gaps
/// (`Balances.transfer_keep_alive` is index 3 on Polkadot Asset Hub, but the third entry of the
/// list). The runtime dispatches by the index, so the call index has to come from the metadata.
final class RuntimeMetadataCallIndexTests: XCTestCase {
    func testEveryFixtureCallIsFoundAtTheIndexTheChainPublished() throws {
        for name in RuntimeMetadataFixture.Name.allCases {
            let runtime = try FixtureRuntime(name)

            for pallet in runtime.fixture.manifest.pallets {
                XCTAssertEqual(
                    runtime.metadata.getModuleIndex(pallet.name),
                    pallet.moduleIndex,
                    "\(name) \(pallet.name) module index"
                )

                for call in pallet.calls {
                    XCTAssertEqual(
                        try runtime.metadata.getCallIndex(in: pallet.name, callName: call.name),
                        call.index,
                        "\(name) \(pallet.name).\(call.name)"
                    )
                }
            }
        }
    }

    func testBalancesCallIndexesSkipTheRemovedCalls() throws {
        let runtime = try FixtureRuntime(.polkadotAssetHub)
        let balances = try XCTUnwrap(
            runtime.fixture.manifest.pallets.first { $0.name == "Balances" }
        )

        let indexes = try [
            "transfer_allow_death",
            "force_transfer",
            "transfer_keep_alive",
            "transfer_all",
            "force_set_balance",
            "burn",
        ].map { try runtime.metadata.getCallIndex(in: "Balances", callName: $0) }
        XCTAssertEqual(indexes, [0, 2, 3, 4, 8, 10])

        // The fixture has to keep the gaps, or the checks above prove nothing.
        let positions = ["transfer_keep_alive", "transfer_all", "burn"].map { name in
            balances.calls.first { $0.name == name }?.position
        }
        XCTAssertEqual(positions, [2, 3, 8])
    }

    func testCallNamesAreMatchedIgnoringCase() throws {
        let runtime = try FixtureRuntime(.polkadotAssetHub)

        XCTAssertEqual(
            try runtime.metadata.getCallIndex(in: "balances", callName: "Transfer_Keep_Alive"),
            3
        )
        XCTAssertEqual(
            try runtime.metadata.getCallIndex(
                in: "polkadotXcm",
                callName: "limited_teleport_assets"
            ),
            9
        )
    }

    func testUnknownPalletOrCallHasNoIndex() throws {
        let runtime = try FixtureRuntime(.polkadotAssetHub)

        XCTAssertNil(try runtime.metadata.getCallIndex(in: "Balances", callName: "transfer"))
        XCTAssertNil(try runtime.metadata.getCallIndex(in: "NoSuchPallet", callName: "burn"))
    }

    func testFunctionLookupByIndexSkipsTheGaps() throws {
        let runtime = try FixtureRuntime(.polkadotAssetHub)
        let balances = try XCTUnwrap(runtime.metadata.modules.first { $0.name == "Balances" })

        func name(at index: UInt8) throws -> String? {
            try runtime.metadata.getFunction(in: balances, at: index)?.name
        }

        XCTAssertEqual(try name(at: 0), "transfer_allow_death")
        XCTAssertNil(try name(at: 1))
        XCTAssertEqual(try name(at: 3), "transfer_keep_alive")
        XCTAssertEqual(try name(at: 4), "transfer_all")
        XCTAssertNil(try name(at: 7))
        XCTAssertEqual(try name(at: 10), "burn")
        XCTAssertNil(try name(at: 11))
    }

    func testMetadataWithoutCallIndexesUsesTheListPosition() throws {
        let metadata = try RuntimeMetadata.v1(
            modules: [
                RuntimeMetadataV1.ModuleMetadata(
                    name: "Pallet",
                    storage: nil,
                    calls: ["first", "second", "third"].map {
                        RuntimeMetadataV1.FunctionMetadata(
                            name: $0,
                            arguments: [],
                            documentation: []
                        )
                    },
                    events: nil,
                    constants: [],
                    errors: [],
                    index: 7
                ),
            ],
            extrinsic: RuntimeMetadataV1.ExtrinsicMetadata(version: 1, signedExtensions: [])
        )
        let module = try XCTUnwrap(metadata.modules.first)

        XCTAssertEqual(try metadata.getCallIndex(in: "Pallet", callName: "first"), 0)
        XCTAssertEqual(try metadata.getCallIndex(in: "Pallet", callName: "third"), 2)
        XCTAssertEqual(try metadata.getFunction(in: module, at: 1)?.name, "second")
        XCTAssertNil(try metadata.getFunction(in: module, at: 3))
    }

    func testCallIndexOfAFunctionMetadataConformerWithoutOneIsNil() {
        struct Custom: RuntimeFunctionMetadata {
            let name = "custom"
            let arguments: [RuntimeFunctionArgumentMetadata] = []
            let documentation: [String] = []
        }

        XCTAssertNil(Custom().callIndex)
    }
}
