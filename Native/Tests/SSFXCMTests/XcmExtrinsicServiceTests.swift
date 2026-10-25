import BigInt
import RobinHood
import SSFExtrinsicKit
import SSFModels
import SSFRuntimeCodingService
import SSFSigner
import SSFUtils
import XCTest

@testable import SSFXCM

final class XcmExtrinsicServiceTests: XCTestCase {
    var service: XcmExtrinsicServiceProtocol?
    var extrinsicBuilder: XcmExtrinsicBuilderProtocolMock?
    var versionFetcher: XcmVersionFetchingMock?
    var chainRegistry: ChainRegistryProtocolMock?
    var depsContainer: XcmDependencyContainerProtocolMock?
    var determiner: CallPathDeterminerMock?

    override func setUp() {
        super.setUp()

        let extrinsicBuilder = XcmExtrinsicBuilderProtocolMock()
        let versionFetcher = XcmVersionFetchingMock()
        let chainRegistry = ChainRegistryProtocolMock()
        let depsContainer = XcmDependencyContainerProtocolMock()
        let determiner = CallPathDeterminerMock()

        self.extrinsicBuilder = extrinsicBuilder
        self.versionFetcher = versionFetcher
        self.chainRegistry = chainRegistry
        self.depsContainer = depsContainer
        self.determiner = determiner

        setupDependencies()

        service = XcmExtrinsicService(
            signingWrapper: XcmReadOnlySigner(),
            extrinsicBuilder: extrinsicBuilder,
            xcmVersionFetcher: versionFetcher,
            chainRegistry: chainRegistry,
            depsContainer: depsContainer,
            callPathDeterminer: determiner
        )
    }

    override func tearDown() {
        super.tearDown()
        extrinsicBuilder = nil
        versionFetcher = nil
        chainRegistry = nil
        depsContainer = nil
        determiner = nil
        service = nil
    }

    func testEstimateOriginalFee() async {
        // arrange
        let fromChainId = "0"
        let assetSymbol = "0"
        let destChainId = "0"
        let destAccountId: AccountId = Data()
        let amount = BigUInt()

        for path in TestData.paths {
            determiner?.determineCallPathFromDestReturnValue = path

            // act
            let result = await service?.estimateOriginalFee(
                fromChainId: fromChainId,
                assetSymbol: assetSymbol,
                destChainId: destChainId,
                destAccountId: destAccountId,
                amount: amount
            )
            // assert
            XCTAssertNotNil(result)

            switch result {
            case let .success(info):
                XCTAssertEqual(info.fee, "0")
            case let .failure(error):
                XCTAssertEqual(
                    error.localizedDescription,
                    XcmError.caseNotProcessed.localizedDescription
                )
            case .none:
                XCTFail()
            }
        }
    }

    func testTransfer() async {
        // arrange
        let fromChainId = "0"
        let assetSymbol = "0"
        let destChainId = "0"
        let destAccountId: AccountId = Data()
        let amount = BigUInt()

        for path in TestData.paths {
            determiner?.determineCallPathFromDestReturnValue = path

            // act
            let result = await service?.transfer(
                fromChainId: fromChainId,
                assetSymbol: assetSymbol,
                destChainId: destChainId,
                destAccountId: destAccountId,
                amount: amount
            )
            // assert
            XCTAssertNotNil(result)

            switch result {
            case let .success(value):
                XCTAssertEqual(value, "success")
            case let .failure(error):
                XCTAssertEqual(
                    error.localizedDescription,
                    XcmError.caseNotProcessed.localizedDescription
                )
            case .none:
                XCTFail()
            }
        }
    }

    func testTheTeleportPathsGetTheRequestedAsset() async {
        // The native token paths used to drop the asset and always build the relay token.
        for path in [
            XcmCallPath.xcmPalletLimitedTeleportAssets,
            .polkadotXcmLimitedTeleportAssets,
        ] {
            determiner?.determineCallPathFromDestReturnValue = path

            _ = await service?.estimateOriginalFee(
                fromChainId: "0",
                assetSymbol: "USDt",
                destChainId: "0",
                destAccountId: Data(),
                amount: BigUInt(1)
            )

            XCTAssertEqual(
                extrinsicBuilder?
                    .buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReceivedArguments?
                    .assetSymbol,
                "USDt"
            )
        }
    }

    func testABuilderErrorIsReturnedAsTheResult() async {
        determiner?.determineCallPathFromDestReturnValue = .polkadotXcmLimitedTeleportAssets
        extrinsicBuilder?
            .buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathThrowableError =
            XcmError.directionNotSupported

        let fee = await service?.estimateOriginalFee(
            fromChainId: "0",
            assetSymbol: "0",
            destChainId: "0",
            destAccountId: Data(),
            amount: BigUInt()
        )
        let transfer = await service?.transfer(
            fromChainId: "0",
            assetSymbol: "0",
            destChainId: "0",
            destAccountId: Data(),
            amount: BigUInt()
        )

        guard case let .failure(feeError) = fee, case let .failure(transferError) = transfer else {
            return XCTFail("Both calls must fail")
        }
        XCTAssertEqual("\(feeError)", "\(XcmError.directionNotSupported)")
        XCTAssertEqual("\(transferError)", "\(XcmError.directionNotSupported)")
    }
}

private extension XcmExtrinsicServiceTests {
    private enum TestData {
        static let fromChainData = XcmAssembly.FromChainData(
            chainId: "1",
            cryptoType: .ed25519,
            chainMetadata: nil,
            accountId: Data(),
            chainType: .substrate
        )

        static let fromChain = ChainModel(
            rank: 0,
            disabled: false,
            chainId: "0",
            paraId: "1001",
            name: "test1",
            assets: Set([.init(
                id: "0",
                name: "0",
                symbol: "0",
                precision: 0,
                currencyId: "0",
                existentialDeposit: "0",
                color: "0",
                isUtility: true,
                isNative: true,
                staking: .paraChain
            )]),
            xcm: XcmChain(
                xcmVersion: .V3,
                destWeightIsPrimitive: true,
                availableAssets: [.init(
                    id: "0",
                    symbol: "0"
                )],
                availableDestinations: [.init(
                    chainId: "0",
                    bridgeParachainId: "2",
                    assets: [.init(
                        id: "1",
                        symbol: "1"
                    )]
                )]
            ),
            nodes: Set([ChainNodeModel(
                url: XcmConfig.shared.tokenLocationsSourceUrl,
                name: "test1",
                apikey: nil
            )]),
            addressPrefix: 0,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )

        static let paths: [XcmCallPath] = [
            .xcmPalletLimitedTeleportAssets,
            .polkadotXcmLimitedTeleportAssets,
            .polkadotXcmLimitedReserveTransferAssets,
            .xTokensTransferMultiasset,
            .bridgeProxyBurn,
            .soraBridgeAppBurn,
            .parachainId,
        ]

        static let runtimeProvider = RuntimeProvider(
            operationQueue: OperationQueue(),
            usedRuntimePaths: [:],
            chainMetadata: RuntimeMetadataItem(
                chain: "0",
                version: 0,
                txVersion: 0,
                metadata: Data()
            ),
            chainTypes: Data()
        )

        static let connectionChain = WebSocketEngine(
            connectionName: "test",
            url: XcmConfig.shared.chainsSourceUrl
        )
    }

    func setupDependencies() {
        chainRegistry?.getChainForReturnValue = TestData.fromChain
        versionFetcher?.getVersionForReturnValue = .V3

        let closure: ExtrinsicBuilderClosure = { $0 }
        extrinsicBuilder?
            .buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReturnValue =
            closure
        extrinsicBuilder?
            .buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathReturnValue =
            closure
        extrinsicBuilder?
            .buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathReturnValue =
            closure
        extrinsicBuilder?
            .buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathReturnValue =
            closure
        extrinsicBuilder?
            .buildSoraBridgeAddBurnCurrencyIdAccountIdAmountPathReturnValue =
            closure
        depsContainer?.prepareDepsReturnValue = XcmDeps(extrinsicService: extrinsicService())
    }

    private func extrinsicService() -> ExtrinsicServiceProtocol {
        let extrinsicService = ExtrinsicServiceProtocolMock()
        extrinsicService.estimateFeeRunningInCompletionClosure = { _, _, completion in
            let info = RuntimeDispatchInfo(inclusionFee: .init(
                baseFee: BigUInt(),
                lenFee: BigUInt(),
                adjustedWeightFee: BigUInt()
            ))
            completion(.success(info))
        }

        extrinsicService.submitSignerRunningInCompletionClosure = { _, _, _, completion in
            completion(.success("success"))
        }

        return extrinsicService
    }
}
