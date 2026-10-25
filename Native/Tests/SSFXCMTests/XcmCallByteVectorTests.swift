import BigInt
import RuntimeMetadataFixtures
import SSFModels
import SSFUtils
import XCTest

@testable import SSFXCM

/// The calls the XCM call factory builds, encoded against the metadata of the chain that would
/// run them and compared with exact bytes.
///
/// The expected hex was assembled by hand from the SCALE rules, and decoded again with a separate
/// registry driven decoder over the same fixtures (every vector decodes to the arguments in the
/// comments and consumes every byte). None of it comes from the code under test.
final class XcmCallByteVectorTests: XCTestCase {
    private typealias Chains = XcmTestChains

    private let account = Data(1 ... 32)
    private let accountHex = "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
    private let evmAccount = Data(1 ... 20)
    private let evmAccountHex = "0102030405060708090a0b0c0d0e0f1011121314"

    /// 10^12 as Compact<u128> (five byte big integer) and as u128.
    private let amount = BigUInt(1_000_000_000_000)
    private let compactAmountHex = "070010a5d4e8"
    private let u128AmountHex = "0010a5d4e80000000000000000000000"

    /// WeightLimit::Unlimited
    private let unlimitedHex = "00"

    /// Some(NetworkId::Polkadot), Some(NetworkId::Kusama): index 2 and 3 in V3, V4 and V5.
    private let polkadotNetworkHex = "0102"
    private let kusamaNetworkHex = "0103"

    private var fetcher: XcmAssetMultilocationFetchingMock!
    private var factory: XcmCallFactory!

    override func setUp() {
        super.setUp()
        fetcher = XcmAssetMultilocationFetchingMock()
        factory = XcmCallFactory(assetMultilocationFetcher: fetcher)
    }

    // MARK: - Teleports of the relay chain's token

    func testTeleportFromAssetHubToThePolkadotRelayChain() throws {
        let call = try factory.reserveNativeToken(
            version: .V3,
            assetSymbol: "DOT",
            fromChainModel: Chains.assetHub,
            destChainModel: Chains.polkadot,
            destAccountId: account,
            amount: amount,
            path: .polkadotXcmLimitedTeleportAssets
        )
        let runtime = try XcmFixtureRuntime(.polkadotAssetHub)

        let expected = [
            "1f09", // PolkadotXcm 31, limited_teleport_assets 9
            "03", "01", "00", // dest: V3, parents 1, Here
            "03", "00", "01", "01", polkadotNetworkHex, accountHex, // beneficiary: X1(AccountId32)
            "03", "04", "00", "01", "00", "00", compactAmountHex,
            // assets: [Concrete(1, Here), Fungible]
            "00000000", // fee_asset_item
            unlimitedHex, // weight_limit
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)

        let decoded = try runtime.decode(call: expected)
        XCTAssertEqual(decoded.module, "PolkadotXcm")
        XCTAssertEqual(decoded.call, "limited_teleport_assets")
        XCTAssertEqual(decoded.args["fee_asset_item"], .stringValue("0"))
    }

    func testTeleportFromAssetHubToThePolkadotRelayChainInV4() throws {
        let call = try factory.reserveNativeToken(
            version: .V4,
            assetSymbol: "DOT",
            fromChainModel: Chains.assetHub,
            destChainModel: Chains.polkadot,
            destAccountId: account,
            amount: amount,
            path: .polkadotXcmLimitedTeleportAssets
        )
        let runtime = try XcmFixtureRuntime(.polkadotAssetHub)

        let expected = [
            "1f09",
            "04", "01", "00", // dest: V4, parents 1, Here
            "04", "00", "01", "01", polkadotNetworkHex, accountHex,
            // beneficiary: X1([AccountId32]), the one element array encodes like V3's field
            "04", "04", "01", "00", "00", compactAmountHex,
            // assets: [Asset { id: (1, Here), Fungible }], no Concrete in V4
            "00000000",
            unlimitedHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
        XCTAssertEqual(try runtime.decode(call: expected).call, "limited_teleport_assets")
    }

    func testTeleportFromAssetHubToThePolkadotRelayChainInV5() throws {
        let call = try factory.reserveNativeToken(
            version: .V5,
            assetSymbol: "DOT",
            fromChainModel: Chains.assetHub,
            destChainModel: Chains.polkadot,
            destAccountId: account,
            amount: amount,
            path: .polkadotXcmLimitedTeleportAssets
        )
        let runtime = try XcmFixtureRuntime(.polkadotAssetHub)

        let expected = [
            "1f09",
            "05", "01", "00",
            "05", "00", "01", "01", polkadotNetworkHex, accountHex,
            "05", "04", "01", "00", "00", compactAmountHex,
            "00000000",
            unlimitedHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
        XCTAssertEqual(try runtime.decode(call: expected).call, "limited_teleport_assets")
    }

    func testTeleportFromThePolkadotRelayChainToAssetHub() throws {
        let call = try factory.reserveNativeToken(
            version: .V3,
            assetSymbol: "DOT",
            fromChainModel: Chains.polkadot,
            destChainModel: Chains.assetHub,
            destAccountId: account,
            amount: amount,
            path: .xcmPalletLimitedTeleportAssets
        )
        let runtime = try XcmFixtureRuntime(.polkadot)

        let expected = [
            "6309", // XcmPallet 99, limited_teleport_assets 9
            "03", "00", "01", "00", "a10f", // dest: V3, parents 0, X1(Parachain(1000))
            "03", "00", "01", "01", polkadotNetworkHex, accountHex,
            "03", "04", "00", "00", "00", "00", compactAmountHex,
            // assets: [Concrete(0, Here), ...]
            "00000000",
            unlimitedHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
        XCTAssertEqual(try runtime.decode(call: expected).call, "limited_teleport_assets")
    }

    func testTeleportFromThePolkadotRelayChainToAssetHubInV5() throws {
        let call = try factory.reserveNativeToken(
            version: .V5,
            assetSymbol: "DOT",
            fromChainModel: Chains.polkadot,
            destChainModel: Chains.assetHub,
            destAccountId: account,
            amount: amount,
            path: .xcmPalletLimitedTeleportAssets
        )
        let runtime = try XcmFixtureRuntime(.polkadot)

        let expected = [
            "6309",
            "05", "00", "01", "00", "a10f", // dest: V5, parents 0, X1([Parachain(1000)])
            "05", "00", "01", "01", polkadotNetworkHex, accountHex,
            "05", "04", "00", "00", "00", compactAmountHex,
            "00000000",
            unlimitedHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
        XCTAssertEqual(try runtime.decode(call: expected).call, "limited_teleport_assets")
    }

    func testTeleportBetweenSystemParachainsGoesThroughTheParent() throws {
        // Asset Hub to BridgeHub: the destination is a sibling (parents 1) and the relay token is
        // one level up. The factory used to build parents 0 for both.
        let call = try factory.reserveNativeToken(
            version: .V3,
            assetSymbol: "DOT",
            fromChainModel: Chains.assetHub,
            destChainModel: Chains.bridgeHub,
            destAccountId: account,
            amount: amount,
            path: .polkadotXcmLimitedTeleportAssets
        )
        let runtime = try XcmFixtureRuntime(.polkadotAssetHub)

        let expected = [
            "1f09",
            "03", "01", "01", "00", "a90f", // dest: V3, parents 1, X1(Parachain(1002))
            "03", "00", "01", "01", polkadotNetworkHex, accountHex,
            "03", "04", "00", "01", "00", "00", compactAmountHex, // assets: Concrete(1, Here)
            "00000000",
            unlimitedHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
    }

    // MARK: - Reserve transfers

    func testPolkadotXcmReserveTransferOfUsdtFromAcalaToAssetHub() async throws {
        // Asset Hub is the reserve of USDt, so the destination is its reserve.
        fetcher.versionedMultilocationOriginAssetIdDestChainIdReturnValue = AssetMultilocation(
            id: "usdt",
            symbol: "USDt",
            interiors: [.parachain(1000), .palletInstance(50), .generalIndex(1984)]
        )
        let call = try await factory.polkadotXcmLimitedReserveTransferAssets(
            fromChainModel: Chains.acala,
            version: .V3,
            assetSymbol: "usdt",
            accountId: account,
            destChainModel: Chains.assetHub,
            amount: amount,
            path: .polkadotXcmLimitedReserveTransferAssets
        )
        let runtime = try XcmFixtureRuntime(.acala)

        let expected = [
            "3308", // PolkadotXcm 51, limited_reserve_transfer_assets 8
            "03", "01", "01", "00", "a10f", // dest: V3, parents 1, X1(Parachain(1000))
            "03", "00", "01", "01", polkadotNetworkHex, accountHex,
            "03", "04", "00", // assets: V3, one, Concrete
            "01", "03", "00a10f", "0432", "05011f",
            // parents 1, X3(Parachain 1000, Pallet 50, Index 1984)
            "00", compactAmountHex, // Fungible
            "00000000",
            unlimitedHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
        XCTAssertEqual(
            fetcher.versionedMultilocationOriginAssetIdDestChainIdReceivedArguments?.destChainId,
            Chains.assetHub.parentId
        )
        XCTAssertEqual(try runtime.decode(call: expected).call, "limited_reserve_transfer_assets")
    }

    func testPolkadotXcmReserveTransferOfAssetHubUsdtToAcala() async throws {
        // Asset Hub is the reserve of its own USDt: the location starts at Asset Hub.
        fetcher.versionedMultilocationOriginAssetIdDestChainIdReturnValue = AssetMultilocation(
            id: "usdt-ah",
            symbol: "USDt",
            interiors: [.palletInstance(50), .generalIndex(1984)]
        )
        let call = try await factory.polkadotXcmLimitedReserveTransferAssets(
            fromChainModel: Chains.assetHub,
            version: .V3,
            assetSymbol: "USDt",
            accountId: account,
            destChainModel: Chains.acala,
            amount: amount,
            path: .polkadotXcmLimitedReserveTransferAssets
        )
        let runtime = try XcmFixtureRuntime(.polkadotAssetHub)

        let expected = [
            "1f08", // PolkadotXcm 31, limited_reserve_transfer_assets 8
            "03", "01", "01", "00", "411f", // dest: V3, parents 1, X1(Parachain(2000))
            "03", "00", "01", "01", polkadotNetworkHex, accountHex,
            "03", "04", "00", "00", "02", "0432", "05011f",
            // Concrete(0, X2(Pallet 50, Index 1984))
            "00", compactAmountHex,
            "00000000",
            unlimitedHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
        XCTAssertEqual(try runtime.decode(call: expected).call, "limited_reserve_transfer_assets")
    }

    func testPolkadotXcmReserveTransferOfAssetHubUsdtToAcalaInV4() async throws {
        fetcher.versionedMultilocationOriginAssetIdDestChainIdReturnValue = AssetMultilocation(
            id: "usdt-ah",
            symbol: "USDt",
            interiors: [.palletInstance(50), .generalIndex(1984)]
        )
        let call = try await factory.polkadotXcmLimitedReserveTransferAssets(
            fromChainModel: Chains.assetHub,
            version: .V4,
            assetSymbol: "USDt",
            accountId: account,
            destChainModel: Chains.acala,
            amount: amount,
            path: .polkadotXcmLimitedReserveTransferAssets
        )
        let runtime = try XcmFixtureRuntime(.polkadotAssetHub)

        let expected = [
            "1f08",
            "04", "01", "01", "00", "411f",
            "04", "00", "01", "01", polkadotNetworkHex, accountHex,
            "04", "04", "00", "02", "0432", "05011f", // (0, X2([Pallet 50, Index 1984]))
            "00", compactAmountHex,
            "00000000",
            unlimitedHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
    }

    func testXTokensTransferMultiassetOfUsdtFromAcalaToAssetHub() async throws {
        fetcher.versionedMultilocationOriginAssetIdDestChainIdReturnValue = AssetMultilocation(
            id: "usdt",
            symbol: "USDt",
            interiors: [.parachain(1000), .palletInstance(50), .generalIndex(1984)]
        )
        let call = try await factory.xTokensTransferMultiasset(
            version: .V3,
            assetSymbol: "USDt",
            accountId: account,
            fromChainModel: Chains.acala,
            destChainModel: Chains.assetHub,
            amount: amount,
            path: .xTokensTransferMultiasset
        )
        let runtime = try XcmFixtureRuntime(.acala)

        let expected = [
            "3601", // XTokens 54, transfer_multiasset 1
            "03", "00", "01", "03", "00a10f", "0432", "05011f", "00", compactAmountHex,
            // asset: V3, Concrete(1, X3(Para 1000, Pallet 50, Index 1984)), Fungible
            "03", "01", "02", "00a10f", "01", polkadotNetworkHex, accountHex,
            // dest: 1, X2(Para 1000, Account)
            unlimitedHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
        XCTAssertEqual(try runtime.decode(call: expected).call, "transfer_multiasset")
    }

    func testXTokensTransferMultiassetInV4() async throws {
        fetcher.versionedMultilocationOriginAssetIdDestChainIdReturnValue = AssetMultilocation(
            id: "usdt",
            symbol: "USDt",
            interiors: [.parachain(1000), .palletInstance(50), .generalIndex(1984)]
        )
        let call = try await factory.xTokensTransferMultiasset(
            version: .V4,
            assetSymbol: "USDt",
            accountId: account,
            fromChainModel: Chains.acala,
            destChainModel: Chains.assetHub,
            amount: amount,
            path: .xTokensTransferMultiasset
        )
        let runtime = try XcmFixtureRuntime(.acala)

        let expected = [
            "3601",
            "04", "01", "03", "00a10f", "0432", "05011f", "00", compactAmountHex,
            "04", "01", "02", "00a10f", "01", polkadotNetworkHex, accountHex,
            unlimitedHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
        XCTAssertEqual(try runtime.decode(call: expected).call, "transfer_multiasset")
    }

    func testXTokensTransferMultiassetKeepsTheParentsTheConfigStates() async throws {
        // The shipped locations file lists ASTR with "parents": 0 and no junctions. Deriving the
        // parents from the junctions turned that into the relay chain's location.
        fetcher.versionedMultilocationOriginAssetIdDestChainIdReturnValue = AssetMultilocation(
            id: "astr",
            symbol: "ASTR",
            parents: 0,
            interiors: []
        )
        let call = try await factory.xTokensTransferMultiasset(
            version: .V3,
            assetSymbol: "ASTR",
            accountId: account,
            fromChainModel: Chains.acala,
            destChainModel: Chains.assetHub,
            amount: amount,
            path: .xTokensTransferMultiasset
        )
        let runtime = try XcmFixtureRuntime(.acala)

        let expected = [
            "3601",
            "03", "00", "00", "00", "00", compactAmountHex, // asset: Concrete(0, Here)
            "03", "01", "02", "00a10f", "01", polkadotNetworkHex, accountHex,
            unlimitedHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
    }

    func testXTokensTransferMultiassetConvertsAV1GeneralKey() async throws {
        // The locations file still has V1 keys (lcDOT: 0x040d000000). V3 and later take
        // GeneralKey { length, data: [u8; 32] }: the length of the key and its bytes zero padded.
        fetcher.versionedMultilocationOriginAssetIdDestChainIdReturnValue = AssetMultilocation(
            id: "lcdot",
            symbol: "lcDOT",
            interiors: [.parachain(2000), .generalKey(Data([0x04, 0x0D, 0, 0, 0]))]
        )
        let call = try await factory.xTokensTransferMultiasset(
            version: .V3,
            assetSymbol: "lcDOT",
            accountId: account,
            fromChainModel: Chains.acala,
            destChainModel: Chains.assetHub,
            amount: amount,
            path: .xTokensTransferMultiasset
        )
        let runtime = try XcmFixtureRuntime(.acala)

        let expected = [
            "3601",
            "03", "00", "01", "02", "00411f", // Concrete(1, X2(Para 2000, ...
            "06", "05", "040d000000", String(repeating: "00", count: 27), // GeneralKey(5, data)
            "00", compactAmountHex,
            "03", "01", "02", "00a10f", "01", polkadotNetworkHex, accountHex,
            unlimitedHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
        XCTAssertEqual(try runtime.decode(call: expected).call, "transfer_multiasset")
    }

    // MARK: - SORA bridge

    func testBridgeBurnToLiberland() throws {
        let call = try factory.bridgeProxyBurn(
            currencyId: Constants.xor,
            destChainModel: Chains.liberland,
            accountId: account,
            amount: amount,
            path: .bridgeProxyBurn
        )
        let runtime = try XcmFixtureRuntime(.sora)

        let expected = [
            "6700", // BridgeProxy 103, burn 0
            "01", "05", // network: Sub(Liberland)
            Constants.xorCode, // asset: AssetId32 { code }
            "02", accountHex, // recipient: Liberland(account)
            u128AmountHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
        XCTAssertEqual(try runtime.decode(call: expected).call, "burn")
    }

    func testBridgeBurnToThePolkadotRelayChain() throws {
        let call = try factory.bridgeProxyBurn(
            currencyId: Constants.xor,
            destChainModel: Chains.polkadot,
            accountId: account,
            amount: amount,
            path: .bridgeProxyBurn
        )
        let runtime = try XcmFixtureRuntime(.sora)

        let expected = [
            "6700",
            "01", "02", // network: Sub(Polkadot)
            Constants.xorCode,
            "03", "03", "01", "01", "01", polkadotNetworkHex, accountHex,
            // Parachain(V3 1, X1(AccountId32))
            u128AmountHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
    }

    func testBridgeBurnToAcalaUsesParentsOne() throws {
        let call = try factory.bridgeProxyBurn(
            currencyId: Constants.xor,
            destChainModel: Chains.acala,
            accountId: account,
            amount: amount,
            path: .bridgeProxyBurn
        )
        let runtime = try XcmFixtureRuntime(.sora)

        let expected = [
            "6700",
            "01", "02", // Acala is reached through the Polkadot bridge
            Constants.xorCode,
            "03", "03", "01", "02", "00411f", "01", polkadotNetworkHex, accountHex,
            // 1, X2(Para 2000, Account)
            u128AmountHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
    }

    func testBridgeBurnToAstarUsesParentsOne() throws {
        // Every parachain, not only Acala: the factory used to build parents 0 for the others.
        let call = try factory.bridgeProxyBurn(
            currencyId: Constants.xor,
            destChainModel: Chains.astar,
            accountId: account,
            amount: amount,
            path: .bridgeProxyBurn
        )
        let runtime = try XcmFixtureRuntime(.sora)

        let expected = [
            "6700",
            "01", "02",
            Constants.xorCode,
            "03", "03", "01", "02", "00591f", "01", polkadotNetworkHex, accountHex,
            // 1, X2(Para 2006, Account)
            u128AmountHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
        XCTAssertEqual(try runtime.decode(call: expected).call, "burn")
    }

    func testBridgeBurnToTheKusamaRelayChain() throws {
        let call = try factory.bridgeProxyBurn(
            currencyId: Constants.xor,
            destChainModel: Chains.kusama,
            accountId: account,
            amount: amount,
            path: .bridgeProxyBurn
        )
        let runtime = try XcmFixtureRuntime(.sora)

        let expected = [
            "6700",
            "01", "01", // network: Sub(Kusama)
            Constants.xorCode,
            "03", "03", "01", "01", "01", kusamaNetworkHex, accountHex,
            u128AmountHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
    }

    func testBridgeBurnToKusamaAssetHub() throws {
        let call = try factory.bridgeProxyBurn(
            currencyId: Constants.xor,
            destChainModel: Chains.kusamaAssetHub,
            accountId: account,
            amount: amount,
            path: .bridgeProxyBurn
        )
        let runtime = try XcmFixtureRuntime(.sora)

        let expected = [
            "6700",
            "01", "01",
            Constants.xorCode,
            "03", "03", "01", "02", "00a10f", "01", kusamaNetworkHex, accountHex,
            u128AmountHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
    }

    func testBridgeBurnToEthereumNamesTheNetworkByAnH256ChainId() throws {
        let call = try factory.bridgeProxyBurn(
            currencyId: Constants.xor,
            destChainModel: Chains.ethereum,
            accountId: evmAccount,
            amount: amount,
            path: .bridgeProxyBurn
        )
        let runtime = try XcmFixtureRuntime(.sora)

        let expected = [
            "6700",
            "00", String(repeating: "00", count: 31), "01", // network: EVM(H256 of chain id 1)
            Constants.xorCode,
            "00", evmAccountHex, // recipient: EVM(H160)
            u128AmountHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)

        let decoded = try runtime.decode(call: expected)
        XCTAssertEqual(decoded.call, "burn")
    }

    func testBridgeBurnToAnEvmNetworkWithAHexChainId() throws {
        let call = try factory.bridgeProxyBurn(
            currencyId: Constants.xor,
            destChainModel: Chains.bnbChain,
            accountId: evmAccount,
            amount: amount,
            path: .bridgeProxyBurn
        )
        let runtime = try XcmFixtureRuntime(.sora)

        let expected = [
            "6700",
            "00", String(repeating: "00", count: 31), "38", // EVM(H256 of 0x38)
            Constants.xorCode,
            "00", evmAccountHex,
            u128AmountHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
    }

    func testLiberlandBurnOfTheNativeTokenToSora() throws {
        let call = factory.soraBridgeAppBurn(
            currencyId: nil,
            accountId: account,
            amount: amount,
            path: .soraBridgeAppBurn
        )
        let runtime = try XcmFixtureRuntime(.liberland)

        let expected = [
            "5103", // SoraBridgeApp 81, burn 3
            "00", // network: Mainnet
            "00", // asset: LLD
            "01", accountHex, // recipient: Sora(account)
            u128AmountHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)

        let decoded = try runtime.decode(call: expected)
        XCTAssertEqual(decoded.module, "SoraBridgeApp")
        XCTAssertEqual(decoded.args["amount"], .stringValue("1000000000000"))
    }

    func testLiberlandBurnOfAnotherAssetToSora() throws {
        let call = factory.soraBridgeAppBurn(
            currencyId: "7",
            accountId: account,
            amount: amount,
            path: .soraBridgeAppBurn
        )
        let runtime = try XcmFixtureRuntime(.liberland)

        let expected = [
            "5103", "00", "01", "07000000", "01", accountHex, u128AmountHex,
        ].joined()
        XCTAssertEqual(try runtime.encode(call).hex, expected)
    }
}

// MARK: - Test data

private enum Constants {
    /// The XOR asset code on SORA, as the 32 byte code and as the hex the call factory takes.
    static let xorCode = "02" + String(repeating: "00", count: 31)
    static let xor = "0x" + xorCode
}

/// A fixture's runtime metadata with the production type registry built from it.
private struct XcmFixtureRuntime {
    struct DecodedCall {
        let module: String
        let call: String
        let args: [String: JSON]
    }

    let fixture: RuntimeMetadataFixture
    let catalog: TypeRegistryCatalog

    init(_ name: RuntimeMetadataFixture.Name) throws {
        fixture = try RuntimeMetadataFixture.load(name)
        let metadata = try RuntimeMetadata(scaleDecoder: ScaleDecoder(data: fixture.metadata))
        catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            Data(#"{"types":{}}"#.utf8),
            runtimeMetadata: metadata,
            usedRuntimePaths: [:]
        )
    }

    func encode<T: Encodable>(_ call: T) throws -> Data {
        let encoder = DynamicScaleEncoder(
            registry: catalog,
            version: UInt64(fixture.manifest.specVersion)
        )
        try encoder.append(call, ofType: GenericType.call.name)
        return try encoder.encode()
    }

    func decode(call hex: String) throws -> DecodedCall {
        let decoder = try DynamicScaleDecoder(
            data: Data(hex: hex),
            registry: catalog,
            version: UInt64(fixture.manifest.specVersion)
        )
        let json = try decoder.read(type: GenericType.call.name)
        XCTAssertEqual(decoder.remained, 0, "the call must consume every byte")

        let call = try json.plainMap(to: RuntimeCall<JSON>.self)
        return DecodedCall(
            module: call.moduleName,
            call: call.callName,
            args: call.args.dictValue ?? [:]
        )
    }
}

private extension Data {
    init(hex: String) {
        var bytes = [UInt8]()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(UInt8(hex[index ..< next], radix: 16)!)
            index = next
        }
        self.init(bytes)
    }

    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
