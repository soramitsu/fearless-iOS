import BigInt
import SSFModels
import SSFUtils
import XCTest

@testable import SSFXCM

/// What the call factory refuses to build. The calls it does build are checked byte for byte in
/// `XcmCallByteVectorTests`.
final class XcmCallFactoryTests: XCTestCase {
    private typealias Chains = XcmTestChains

    private let account = Data(repeating: 7, count: 32)
    private var fetcher: XcmAssetMultilocationFetchingMock!
    private var factory: XcmCallFactory!

    override func setUp() {
        super.setUp()
        fetcher = XcmAssetMultilocationFetchingMock()
        fetcher.versionedMultilocationOriginAssetIdDestChainIdReturnValue = TestData.usdtOnAssetHub
        factory = XcmCallFactory(assetMultilocationFetcher: fetcher)
    }

    override func tearDown() {
        fetcher = nil
        factory = nil
        super.tearDown()
    }

    // MARK: - Versions

    func testV1IsRefusedByEveryXcmCall() async {
        let refusal = XcmError.unsupportedXcmVersion(.V1)

        assertRefused(refusal) {
            _ = try self.factory.reserveNativeToken(
                version: .V1,
                assetSymbol: "DOT",
                fromChainModel: Chains.assetHub,
                destChainModel: Chains.polkadot,
                destAccountId: self.account,
                amount: 1,
                path: .polkadotXcmLimitedTeleportAssets
            )
        }
        await assertRefusedAsync(refusal) {
            _ = try await self.factory.xTokensTransferMultiasset(
                version: .V1,
                assetSymbol: "USDt",
                accountId: self.account,
                fromChainModel: Chains.acala,
                destChainModel: Chains.assetHub,
                amount: 1,
                path: .xTokensTransferMultiasset
            )
        }
        await assertRefusedAsync(refusal) {
            _ = try await self.factory.polkadotXcmLimitedReserveTransferAssets(
                fromChainModel: Chains.assetHub,
                version: .V1,
                assetSymbol: "USDt",
                accountId: self.account,
                destChainModel: Chains.acala,
                amount: 1,
                path: .polkadotXcmLimitedReserveTransferAssets
            )
        }
    }

    func testV3V4AndV5AreBuilt() throws {
        for version in [XcmCallFactoryVersion.V3, .V4, .V5] {
            let call = try factory.reserveNativeToken(
                version: version,
                assetSymbol: "DOT",
                fromChainModel: Chains.assetHub,
                destChainModel: Chains.polkadot,
                destAccountId: account,
                amount: 1,
                path: .polkadotXcmLimitedTeleportAssets
            )

            XCTAssertEqual(call.args.weightLimit, .unlimited)
            XCTAssertEqual(call.moduleName, "polkadotXcm")
            XCTAssertEqual(call.callName, "limited_teleport_assets")
        }
    }

    // MARK: - Teleports

    func testATeleportMovesOnlyTheRelayChainsToken() {
        // The asset used to be dropped: a request for USDt built a DOT transfer.
        assertRefused(.noAvailableXcmAsset(symbol: "USDt")) {
            _ = try self.factory.reserveNativeToken(
                version: .V3,
                assetSymbol: "USDt",
                fromChainModel: Chains.assetHub,
                destChainModel: Chains.polkadot,
                destAccountId: self.account,
                amount: 1,
                path: .polkadotXcmLimitedTeleportAssets
            )
        }
    }

    func testATeleportToAParachainOutsideTheSystemRangeIsRefused() {
        // Only the relay chain and the system parachains trust each other's teleports.
        assertRefused(.directionNotSupported) {
            _ = try self.factory.reserveNativeToken(
                version: .V3,
                assetSymbol: "DOT",
                fromChainModel: Chains.assetHub,
                destChainModel: Chains.acala,
                destAccountId: self.account,
                amount: 1,
                path: .polkadotXcmLimitedTeleportAssets
            )
        }
        assertRefused(.directionNotSupported) {
            _ = try self.factory.reserveNativeToken(
                version: .V3,
                assetSymbol: "DOT",
                fromChainModel: Chains.polkadot,
                destChainModel: Chains.acala,
                destAccountId: self.account,
                amount: 1,
                path: .xcmPalletLimitedTeleportAssets
            )
        }
    }

    func testATeleportBetweenTwoRelayChainsIsRefused() {
        assertRefused(.directionNotSupported) {
            _ = try self.factory.reserveNativeToken(
                version: .V3,
                assetSymbol: "DOT",
                fromChainModel: Chains.polkadot,
                destChainModel: Chains.kusama,
                destAccountId: self.account,
                amount: 1,
                path: .xcmPalletLimitedTeleportAssets
            )
        }
    }

    func testChainsOfAnotherRelayNetworkAreRefused() async {
        // `parents: 1` from Polkadot Asset Hub is Polkadot, whatever chain the caller meant.
        assertRefused(.directionNotSupported) {
            _ = try self.factory.reserveNativeToken(
                version: .V3,
                assetSymbol: "DOT",
                fromChainModel: Chains.assetHub,
                destChainModel: Chains.kusamaAssetHub,
                destAccountId: self.account,
                amount: 1,
                path: .polkadotXcmLimitedTeleportAssets
            )
        }
        await assertRefusedAsync(.directionNotSupported) {
            _ = try await self.factory.xTokensTransferMultiasset(
                version: .V3,
                assetSymbol: "USDt",
                accountId: self.account,
                fromChainModel: Chains.acala,
                destChainModel: Chains.kusamaAssetHub,
                amount: 1,
                path: .xTokensTransferMultiasset
            )
        }
    }

    func testAParachainWithoutItsRelayChainIsRefused() {
        let orphan = Chains.chain(id: "orphan", paraId: "1000", name: "Orphan")

        assertRefused(.missingParachainId(chainId: "orphan")) {
            _ = try self.factory.reserveNativeToken(
                version: .V3,
                assetSymbol: "DOT",
                fromChainModel: Chains.polkadot,
                destChainModel: orphan,
                destAccountId: self.account,
                amount: 1,
                path: .xcmPalletLimitedTeleportAssets
            )
        }
    }

    // MARK: - Reserve transfers

    func testReserveTransfersOfTheRelayChainsTokenAreRefused() async {
        // Since the Asset Hub migration pallet_xcm rejects them (InvalidAssetUnknownReserve), and
        // the relay chain no longer holds the parachains' DOT for XTokens.
        fetcher.versionedMultilocationOriginAssetIdDestChainIdReturnValue = TestData.dot

        await assertRefusedAsync(.directionNotSupported) {
            _ = try await self.factory.xTokensTransferMultiasset(
                version: .V3,
                assetSymbol: "DOT",
                accountId: self.account,
                fromChainModel: Chains.acala,
                destChainModel: Chains.assetHub,
                amount: 1,
                path: .xTokensTransferMultiasset
            )
        }
        await assertRefusedAsync(.directionNotSupported) {
            _ = try await self.factory.polkadotXcmLimitedReserveTransferAssets(
                fromChainModel: Chains.assetHub,
                version: .V3,
                assetSymbol: "DOT",
                accountId: self.account,
                destChainModel: Chains.acala,
                amount: 1,
                path: .polkadotXcmLimitedReserveTransferAssets
            )
        }
    }

    func testPolkadotXcmHasNoReserveTransferToTheRelayChain() async {
        await assertRefusedAsync(.directionNotSupported) {
            _ = try await self.factory.polkadotXcmLimitedReserveTransferAssets(
                fromChainModel: Chains.assetHub,
                version: .V3,
                assetSymbol: "USDt",
                accountId: self.account,
                destChainModel: Chains.polkadot,
                amount: 1,
                path: .polkadotXcmLimitedReserveTransferAssets
            )
        }
    }

    func testXTokensWithAPrimitiveDestWeightIsRefused() async {
        // `transfer_multiasset(asset, dest, dest_weight: u64)` is gone from every runtime.
        let legacyAcala = Chains.chain(
            id: Chains.acala.chainId,
            parentId: Chains.polkadotId,
            paraId: "2000",
            name: "Acala",
            xcm: Chains.xcm(assets: [("usdt", "USDt")], destWeightIsPrimitive: true)
        )

        await assertRefusedAsync(.unsupportedRemoteXcmVersion) {
            _ = try await self.factory.xTokensTransferMultiasset(
                version: .V3,
                assetSymbol: "USDt",
                accountId: self.account,
                fromChainModel: legacyAcala,
                destChainModel: Chains.assetHub,
                amount: 1,
                path: .xTokensTransferMultiasset
            )
        }
    }

    func testAnAssetTheOriginDoesNotSendIsRefused() async {
        await assertRefusedAsync(.noAvailableXcmAsset(symbol: "GLMR")) {
            _ = try await self.factory.xTokensTransferMultiasset(
                version: .V3,
                assetSymbol: "GLMR",
                accountId: self.account,
                fromChainModel: Chains.acala,
                destChainModel: Chains.assetHub,
                amount: 1,
                path: .xTokensTransferMultiasset
            )
        }
    }

    func testAGeneralKeyLongerThan32BytesIsRefused() async {
        fetcher.versionedMultilocationOriginAssetIdDestChainIdReturnValue = AssetMultilocation(
            id: "usdt",
            symbol: "USDt",
            interiors: [.parachain(2000), .generalKey(Data(repeating: 1, count: 33))]
        )

        await assertRefusedAsync(.unsupportedRemoteXcmVersion) {
            _ = try await self.factory.xTokensTransferMultiasset(
                version: .V3,
                assetSymbol: "USDt",
                accountId: self.account,
                fromChainModel: Chains.acala,
                destChainModel: Chains.assetHub,
                amount: 1,
                path: .xTokensTransferMultiasset
            )
        }
    }

    func testARecipientOfTheWrongLengthIsRefused() async {
        // A 20 byte account in AccountId32 used to encode as 20 bytes.
        await assertRefusedAsync(.invalidRecipientLength(expected: 32, actual: 20)) {
            _ = try await self.factory.polkadotXcmLimitedReserveTransferAssets(
                fromChainModel: Chains.assetHub,
                version: .V3,
                assetSymbol: "USDt",
                accountId: Data(repeating: 1, count: 20),
                destChainModel: Chains.acala,
                amount: 1,
                path: .polkadotXcmLimitedReserveTransferAssets
            )
        }
    }

    // MARK: - SORA bridge

    func testABurnToANetworkWithoutASoraBridgeIsRefused() {
        assertRefused(.unsupportedBridgeNetwork(chainId: Chains.westend.chainId)) {
            _ = try self.factory.bridgeProxyBurn(
                currencyId: TestData.xor,
                destChainModel: Chains.westend,
                accountId: self.account,
                amount: 1,
                path: .bridgeProxyBurn
            )
        }
    }

    func testABurnToSoraItselfIsRefused() {
        assertRefused(.directionNotSupported) {
            _ = try self.factory.bridgeProxyBurn(
                currencyId: TestData.xor,
                destChainModel: Chains.soraMainnet,
                accountId: self.account,
                amount: 1,
                path: .bridgeProxyBurn
            )
        }
    }

    func testABurnToAnEvmNetworkNeedsA20ByteRecipient() {
        assertRefused(.invalidRecipientLength(expected: 20, actual: 32)) {
            _ = try self.factory.bridgeProxyBurn(
                currencyId: TestData.xor,
                destChainModel: Chains.ethereum,
                accountId: self.account,
                amount: 1,
                path: .bridgeProxyBurn
            )
        }
    }

    func testABurnToAnEvmNetworkWithAChainIdThatIsNoNumberIsRefused() {
        // `BigUInt(stringLiteral:)` crashed on such an id.
        let broken = Chains.chain(id: "eth-mainnet", name: "Ethereum", options: [.ethereum])

        assertRefused(.invalidEvmChainId("eth-mainnet")) {
            _ = try self.factory.bridgeProxyBurn(
                currencyId: TestData.xor,
                destChainModel: broken,
                accountId: Data(repeating: 1, count: 20),
                amount: 1,
                path: .bridgeProxyBurn
            )
        }
    }

    func testABurnToAParachainWithoutItsRelayChainIsRefused() {
        let orphan = Chains.chain(
            id: "orphan",
            parentId: Chains.polkadotId,
            name: "Orphan without a parachain id"
        )

        assertRefused(.missingParachainId(chainId: "orphan")) {
            _ = try self.factory.bridgeProxyBurn(
                currencyId: TestData.xor,
                destChainModel: orphan,
                accountId: self.account,
                amount: 1,
                path: .bridgeProxyBurn
            )
        }
    }

    func testSoraBridgeAppBurn() {
        let call = factory.soraBridgeAppBurn(
            currencyId: nil,
            accountId: account,
            amount: 1,
            path: .soraBridgeAppBurn
        )

        XCTAssertEqual(call.moduleName, "soraBridgeApp")
        XCTAssertEqual(call.callName, "burn")
        XCTAssertEqual(call.args.recipient, .sora(account))
    }
}

private extension XcmCallFactoryTests {
    enum TestData {
        static let xor = "0x02" + String(repeating: "00", count: 31)

        static let usdtOnAssetHub = AssetMultilocation(
            id: "usdt-ah",
            symbol: "USDt",
            interiors: [.palletInstance(50), .generalIndex(1984)]
        )

        /// The relay chain's token: no junctions, reached through the parent.
        static let dot = AssetMultilocation(id: "dot", symbol: "DOT", interiors: [])
    }

    func assertRefused(
        _ expected: XcmError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () throws -> Void
    ) {
        do {
            try body()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual("\(error)", "\(expected)", file: file, line: line)
        }
    }

    func assertRefusedAsync(
        _ expected: XcmError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> Void
    ) async {
        do {
            try await body()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual("\(error)", "\(expected)", file: file, line: line)
        }
    }
}
