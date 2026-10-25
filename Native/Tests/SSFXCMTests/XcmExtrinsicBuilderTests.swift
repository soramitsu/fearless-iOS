import BigInt
import SSFModels
import SSFUtils
import XCTest

@testable import SSFXCM

final class XcmExtrinsicBuilderTests: XCTestCase {
    var builder: XcmExtrinsicBuilderProtocol?
    var callFactory: XcmCallFactoryProtocolMock?

    override func setUp() {
        super.setUp()
        let callFactory = XcmCallFactoryProtocolMock()
        callFactory
            .reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReturnValue =
            createRuntimeCall(TestData.reserveTransferCall)
        callFactory
            .xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathReturnValue =
            createRuntimeCall(TestData.xTokenMultiassetCall)
        callFactory
            .polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathReturnValue =
            createRuntimeCall(TestData.reserveTransferCall)
        callFactory
            .bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathReturnValue =
            createRuntimeCall(TestData.bridgeProxyCall)
        callFactory
            .soraBridgeAppBurnCurrencyIdAccountIdAmountPathReturnValue =
            createRuntimeCall(TestData.liberlandBurnCall)

        self.callFactory = callFactory

        builder = XcmExtrinsicBuilder(callFactory: callFactory)
    }

    override func tearDown() {
        super.tearDown()
        callFactory = nil
        builder = nil
    }

    func testBuildReserveNativeTokenExtrinsicBuilderClosure() throws {
        // arrange
        let version: XcmCallFactoryVersion = .V3
        let destAccountId: AccountId = Data()
        let fromChainModel: ChainModel = TestData.chainModel
        let destChainModel: ChainModel = TestData.chainModel
        let amount = BigUInt()
        let path: XcmCallPath = .parachainId

        // act
        let closure = try builder?.buildReserveNativeTokenExtrinsicBuilderClosure(
            version: version,
            assetSymbol: "DOT",
            fromChainModel: fromChainModel,
            destChainModel: destChainModel,
            destAccountId: destAccountId,
            amount: amount,
            path: path
        )

        // assert
        XCTAssertNotNil(closure)
        XCTAssertEqual(
            callFactory?
                .reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathCallsCount,
            1
        )
        XCTAssertEqual(
            callFactory?
                .reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReceivedArguments?
                .assetSymbol,
            "DOT"
        )
    }

    func testAFactoryRefusalIsThrownByTheBuilder() {
        callFactory?
            .reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathThrowableError =
            XcmError.unsupportedXcmVersion(.V1)

        XCTAssertThrowsError(try builder?.buildReserveNativeTokenExtrinsicBuilderClosure(
            version: .V1,
            assetSymbol: "DOT",
            fromChainModel: TestData.chainModel,
            destChainModel: TestData.chainModel,
            destAccountId: Data(),
            amount: BigUInt(),
            path: .polkadotXcmLimitedTeleportAssets
        )) { error in
            XCTAssertEqual("\(error)", "\(XcmError.unsupportedXcmVersion(.V1))")
        }
    }

    func testBuildXTokensTransferMultiassetExtrinsicBuilderClosure() async throws {
        // arrange
        let assetSymbol = "0"
        let version: XcmCallFactoryVersion = .V3
        let accountId: AccountId = Data()
        let fromChainModel: ChainModel = TestData.chainModel
        let destChainModel: ChainModel = TestData.chainModel
        let amount = BigUInt()
        let path: XcmCallPath = .parachainId

        // act
        let closure = try await builder?.buildXTokensTransferMultiassetExtrinsicBuilderClosure(
            assetSymbol: assetSymbol,
            version: version,
            accountId: accountId,
            fromChainModel: fromChainModel,
            destChainModel: destChainModel,
            amount: amount,
            path: path
        )

        // assert
        XCTAssertNotNil(closure)
        XCTAssertEqual(
            callFactory?
                .xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathCallsCount,
            1
        )
    }

    func testBuildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosure() async throws {
        // arrange
        let fromChainModel: ChainModel = TestData.chainModel
        let version: XcmCallFactoryVersion = .V3
        let assetSymbol = "0"
        let accountId: AccountId = Data()
        let destChainModel: ChainModel = TestData.chainModel
        let amount = BigUInt()
        let path: XcmCallPath = .parachainId

        // act
        let closure = try await builder?
            .buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosure(
                fromChainModel: fromChainModel,
                version: version,
                assetSymbol: assetSymbol,
                accountId: accountId,
                destChainModel: destChainModel,
                amount: amount,
                path: path
            )

        // assert
        XCTAssertNotNil(closure)
        XCTAssertEqual(
            callFactory?
                .polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathCallsCount,
            1
        )
    }

    func testBuildBridgeProxyBurnExtrinsicBuilderClosure() throws {
        // arrange
        let currencyId = "0"
        let accountId: AccountId = Data()
        let destChainModel: ChainModel = TestData.chainModel
        let amount = BigUInt()
        let path: XcmCallPath = .bridgeProxyBurn

        // act
        let closure = try builder?.buildBridgeProxyBurn(
            currencyId: currencyId,
            destChainModel: destChainModel,
            accountId: accountId,
            amount: amount,
            path: path
        )

        // assert
        XCTAssertNotNil(closure)
        XCTAssertEqual(
            callFactory?
                .bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathCallsCount,
            1
        )
    }

    func testBuildSoraBridgeAddBurnExtrinsicBuilderClosure() {
        // arrange
        let accountId: AccountId = Data()
        let amount = BigUInt()
        let path: XcmCallPath = .soraBridgeAppBurn

        // act
        let closure = builder?.buildSoraBridgeAddBurn(
            currencyId: "0",
            accountId: accountId,
            amount: amount,
            path: path
        )

        // assert
        XCTAssertNotNil(closure)
        XCTAssertEqual(
            callFactory?.soraBridgeAppBurnCurrencyIdAccountIdAmountPathCallsCount,
            1
        )
    }
}

private extension XcmExtrinsicBuilderTests {
    private enum TestData {
        static let chainModel = ChainModel(
            rank: 0,
            disabled: false,
            chainId: "0",
            paraId: "0",
            name: "model",
            xcm: XcmChain(
                xcmVersion: .V3,
                destWeightIsPrimitive: false,
                availableAssets: [.init(
                    id: "0",
                    symbol: "0"
                )],
                availableDestinations: [.init(
                    chainId: "1",
                    bridgeParachainId: "2",
                    assets: [.init(
                        id: "0",
                        symbol: "0"
                    )]
                )]
            ),
            nodes: Set([ChainNodeModel(
                url: XcmConfig.shared.tokenLocationsSourceUrl,
                name: "node",
                apikey: nil
            )]),
            addressPrefix: 0,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )

        static let reserveTransferCall = ReserveTransferAssetsCall(
            destination: .V3(.init(
                parents: 0,
                interior: .init(items: [.onlyChild])
            )),
            beneficiary: .V3(.init(
                parents: 1,
                interior: .init(items: [.parachain(2)])
            )),
            assets: .V3([.init(
                assetId: .abstract(Data()),
                fun: .fungible(amount: BigUInt())
            )]),
            weightLimit: .unlimited,
            feeAssetItem: 3
        )

        static let xTokenMultiassetCall = XTokensTransferMultiassetCall(
            asset: .V3(.init(
                assetId: .abstract(Data()),
                fun: .fungible(amount: BigUInt())
            )),
            dest: .V3(.init(
                parents: 0,
                interior: .init(items: [.onlyChild])
            )),
            destWeightLimit: .unlimited
        )

        static let bridgeProxyCall = BridgeProxyBurnCall(
            networkId: .evm(BigUInt()),
            assetId: .init(wrappedValue: "0"),
            recipient: .root,
            amount: BigUInt()
        )

        static let liberlandBurnCall = LiberlandBridgeProxyBurnCall(
            networkId: .mainnet,
            assetId: .init(currencyId: "0"),
            recipient: .sora(Data()),
            amount: BigUInt()
        )
    }

    private func createRuntimeCall<T>(_ args: T) -> RuntimeCall<T> {
        RuntimeCall(moduleName: "", callName: "", args: args)
    }
}
