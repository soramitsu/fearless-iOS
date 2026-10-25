import XCTest

@testable import SSFXCM

final class XcmCallPathTests: XCTestCase {
    func testPathParameters() {
        // arrange
        let moduleName = "parachainInfo"
        let itemName = "parachainId"
        let path = (moduleName: moduleName, itemName: itemName)

        // act
        let xcmPath: XcmCallPath = .parachainId

        // assert
        XCTAssertEqual(xcmPath.path.moduleName, moduleName)
        XCTAssertEqual(xcmPath.path.itemName, itemName)

        XCTAssertEqual(xcmPath.moduleName, moduleName)
        XCTAssertEqual(xcmPath.itemName, itemName)
    }

    func testUsedRuntimePathsParameter() {
        // act
        let usedRuntimePaths = XcmCallPath.usedRuntimePaths

        // assert: one entry per module that any of the paths lives in ...
        XCTAssertEqual(
            Set(usedRuntimePaths.keys),
            Set(XcmCallPath.allCases.map(\.moduleName))
        )
        XCTAssertEqual(usedRuntimePaths.count, 7)

        // ... and every path of a module is listed, not only the last one registered.
        for path in XcmCallPath.allCases {
            XCTAssertTrue(
                usedRuntimePaths[path.moduleName]?.contains(path.itemName) == true,
                "\(path.moduleName).\(path.itemName) is missing"
            )
        }
        XCTAssertEqual(
            Set(usedRuntimePaths["polkadotXcm"] ?? []),
            ["limited_teleport_assets", "limited_reserve_transfer_assets"]
        )
        XCTAssertEqual(Set(usedRuntimePaths["xcmPallet"] ?? []), ["limited_teleport_assets"])
        XCTAssertEqual(Set(usedRuntimePaths["xTokens"] ?? []), ["transfer_multiasset"])
    }

    func testNoPathBuildsAReserveTransferFromTheRelayChain() {
        // Since the Asset Hub migration the relay chains reject it; the unlimited `teleport_assets`
        // and XTokens' `transfer` had no caller.
        let paths = XcmCallPath.allCases.map { "\($0.moduleName).\($0.itemName)" }

        XCTAssertFalse(paths.contains("xcmPallet.limited_reserve_transfer_assets"))
        XCTAssertFalse(paths.contains("polkadotXcm.teleport_assets"))
        XCTAssertFalse(paths.contains("xTokens.transfer"))
    }

    func testThereIsNoReserveWithdrawExtrinsic() {
        // pallet_xcm has no limited_reserve_withdraw_assets, on any chain.
        let items = XcmCallPath.allCases.map(\.itemName)

        XCTAssertFalse(items.contains("limited_reserve_withdraw_assets"))
    }
}
