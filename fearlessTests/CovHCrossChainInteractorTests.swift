import XCTest
import BigInt
import RobinHood
import SSFModels
@testable import fearless

final class CovHCrossChainInteractorTests: XCTestCase {
    func testOriginSelectionLoadsDestinationsDepositAndAssetRecord() throws {
        let fixture = try CovHCrossChainInteractorFixture()
        fixture.interactor.didReceive(originChainAsset: nil)
        XCTAssertEqual(fixture.adapter.subscribed.first?.count, 0)

        fixture.interactor.didReceive(originChainAsset: fixture.origin)
        CovHSendWait.until { fixture.output.origins.count == 1 && fixture.output.deposits.count == 1 && fixture.output.assetRecords == 1 }
        XCTAssertEqual(fixture.output.deposits.count, 1)
        XCTAssertEqual(fixture.output.assetRecords, 1)
        XCTAssertEqual(fixture.output.origins.first?.map(\.asset.id), [fixture.origin.asset.id])
        XCTAssertTrue(fixture.output.destinationAssets.first?.isEmpty == false)
        XCTAssertEqual(fixture.adapter.subscribed.last?.count, 2, "The fee asset and the asset being sent")
        XCTAssertTrue(fixture.adapter.handler === fixture.interactor)
    }

    func testFailedDestinationFetchStillReportsTheOrigin() throws {
        let fixture = try CovHCrossChainInteractorFixture()
        fixture.fetching.result = .failure(CovHSendError.failed)
        fixture.interactor.didReceive(originChainAsset: fixture.origin)
        CovHSendWait.until { fixture.output.origins.count == 1 }
        XCTAssertEqual(fixture.output.destinationAssets.first?.isEmpty, true)
    }

    func testDestinationAccountInfoIsReadOnlyForAReviewedDestination() throws {
        let fixture = try CovHCrossChainInteractorFixture()
        fixture.interactor.fetchDestinationAccountInfo(address: "early")
        fixture.interactor.didReceive(originChainAsset: fixture.origin)
        fixture.interactor.didReceive(destinationChain: fixture.sora)
        fixture.interactor.fetchDestinationAccountInfo(address: "")
        CovHSendWait.until(timeout: 0.2) { false }
        XCTAssertTrue(fixture.output.destinationInfos.isEmpty)
        XCTAssertEqual(fixture.output.destinationInfoErrors, 0)

        let address = try AddressFactory.address(for: Data(repeating: 7, count: 32), chain: fixture.sora)
        fixture.interactor.fetchDestinationAccountInfo(address: address)
        CovHSendWait.until { fixture.output.destinationInfos.count == 1 }
        XCTAssertEqual(fixture.output.destinationInfos.count, 1)

        fixture.interactor.fetchDestinationAccountInfo(address: "not-an-address")
        CovHSendWait.until { fixture.output.destinationInfoErrors == 1 }
        XCTAssertEqual(fixture.output.destinationInfoErrors, 1)

        fixture.interactor.didReceive(destinationChain: fixture.liberland)
        fixture.interactor.fetchDestinationAccountInfo(address: address)
        CovHSendWait.until { fixture.output.destinationInfoErrors == 2 }
        XCTAssertEqual(fixture.output.destinationInfoErrors, 2, "The origin network does not carry the delivered asset")
        CovHSendWait.until { fixture.output.destinationDeposits.count == 2 }
        XCTAssertEqual(fixture.output.destinationDeposits.last, false)
    }

    func testFeesForAnUnreviewedOriginFail() throws {
        let fixture = try CovHCrossChainInteractorFixture()
        let unreviewed = try XCTUnwrap(fixture.liberland.chainAssets.first { $0.asset.id != fixture.origin.asset.id })
        fixture.interactor.estimateFee(originChainAsset: unreviewed, destinationChainModel: fixture.sora, amount: nil)
        CovHSendWait.until { fixture.output.originFees.count == 1 && fixture.output.destinationFees.count == 1 }
        XCTAssertEqual(fixture.output.originFees, [false])
        XCTAssertEqual(fixture.output.destinationFees, [false])
    }

    func testOriginFeeEstimatorFailureIsReported() throws {
        let fixture = try CovHCrossChainInteractorFixture(feeError: CovHSendError.failed)
        fixture.interactor.estimateFee(originChainAsset: fixture.origin, destinationChainModel: fixture.sora, amount: 2)
        CovHSendWait.until { fixture.output.originFees.count == 1 && fixture.output.destinationFees.count == 1 }
        XCTAssertEqual(fixture.output.originFees, [false])
        XCTAssertEqual(fixture.output.destinationFees, [true])
    }

    func testAccountInfoValidationDepsAndErrorText() throws {
        let fixture = try CovHCrossChainInteractorFixture()
        fixture.interactor.handleAccountInfo(result: .success(nil), accountId: Data(repeating: 1, count: 32), chainAsset: fixture.origin)
        XCTAssertEqual(fixture.output.accountInfos, 1)
        XCTAssertEqual(fixture.interactor.validate(address: "", for: fixture.sora), .invalid(""))
        fixture.interactor.deps = nil
        XCTAssertNil(fixture.interactor.deps)
        XCTAssertFalse(CrossChainFormError.destinationExistentialDepositUnavailable.errorDescription?.isEmpty ?? true)
    }

    func testRuntimeItemFailureIsLoggedWithoutSetup() throws {
        let fixture = try CovHCrossChainInteractorFixture(failingRuntimeItems: true)
        CovHSendWait.until { !fixture.logger.errors.isEmpty }
        XCTAssertFalse(fixture.logger.errors.isEmpty)
        XCTAssertEqual(fixture.output.setups, 0)
    }
}

final class CovHCrossChainInteractorFixture {
    let liberland: ChainModel
    let sora: ChainModel
    let origin: ChainAsset
    let wallet = AccountGenerator.generateMetaAccount()
    let output = CovHCrossChainOutputSpy()
    let adapter = CovHSendAccountInfoAdapter()
    let fetching = CovHSendChainAssetFetching()
    let logger = CovHSendLogger()
    let interactor: CrossChainInteractor

    init(symbol: String = "LLD", feeError: Error? = nil, failingRuntimeItems: Bool = false) throws {
        let chains = try CovHCrossChainHarness.registryChains()
        liberland = try XCTUnwrap(chains.first { $0.chainId == ReviewedXcmRouteRegistry.liberlandChainId })
        sora = try XCTUnwrap(chains.first { $0.chainId == ReviewedXcmRouteRegistry.soraChainId })
        let definition = try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == symbol })
        origin = try XCTUnwrap(liberland.chainAssets.first { $0.asset.id == definition.originAssetId })
        fetching.result = .success(sora.chainAssets)
        interactor = CrossChainInteractor(
            reviewedRoute: ReviewedCrossChainRouteContext(definition: definition, providerId: "sora-liberland-xcm"),
            chainAssetFetching: fetching,
            accountInfoSubscriptionAdapter: adapter,
            depsContainer: CrossChainDepsContainer(wallet: wallet),
            originFeeEstimator: CovHCrossChainFeeEstimator(error: feeError),
            runtimeItemRepository: AnyDataProviderRepository(CovHCrossChainRuntimeRepository(fails: failingRuntimeItems)),
            operationQueue: OperationQueue(),
            logger: logger,
            wallet: wallet,
            addressChainDefiner: AddressChainDefiner(
                operationManager: OperationManager(),
                chainModelRepository: AnyDataProviderRepository(CovHCrossChainChainRepository()),
                wallet: wallet
            ),
            existentialDepositService: CovHSendExistentialDeposit(),
            storageRequestPerformer: nil
        )
        interactor.setup(with: output)
    }
}

final class CovHCrossChainOutputSpy: CrossChainInteractorOutput {
    var accountInfos = 0
    var destinationAssets: [[ChainAsset]] = []
    var destinationFees: [Bool] = []
    var originFees: [Bool] = []
    var origins: [[ChainAsset]] = []
    var setups = 0
    var deposits: [Bool] = []
    var destinationInfos: [AccountInfo?] = []
    var destinationInfoErrors = 0
    var destinationDeposits: [Bool] = []
    var assetRecords = 0
    var assetRecordErrors = 0

    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) { accountInfos += 1 }
    func didReceiveAvailableDestChainAssets(_ chainAssets: [ChainAsset]) { destinationAssets.append(chainAssets) }
    func didReceiveDestinationFee(result: Result<Decimal, Error>) { destinationFees.append((try? result.get()) != nil) }
    func didReceiveOriginFee(result: Result<BigUInt, Error>) { originFees.append((try? result.get()) != nil) }
    func didReceiveOrigin(chainAssets: [ChainAsset]) { origins.append(chainAssets) }
    func didSetup() { setups += 1 }
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>) { deposits.append((try? result.get()) != nil) }
    func didReceiveDestinationAccountInfo(accountInfo: AccountInfo?) { destinationInfos.append(accountInfo) }
    func didReceiveDestinationAccountInfoError(error _: Error) { destinationInfoErrors += 1 }
    func didReceiveDestinationExistentialDeposit(result: Result<BigUInt, Error>) { destinationDeposits.append((try? result.get()) != nil) }
    func didReceiveAssetAccountInfo(assetAccountInfo _: AssetAccountInfo?) { assetRecords += 1 }
    func didReceiveAssetAccountInfoError(error _: Error) { assetRecordErrors += 1 }
}

struct CovHCrossChainFeeEstimator: ReviewedCrossChainOriginFeeEstimating {
    let error: Error?

    func estimateOriginFee(definition _: ReviewedXcmRouteDefinition, wallet _: MetaAccountModel, amount _: BigUInt) async throws -> BigUInt {
        if let error { throw error }
        return 1000
    }
}

class CovHCrossChainEmptyRepository<Model: Identifiable>: DataProviderRepositoryProtocol {
    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<Model?> {
        ClosureOperation { nil }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func saveOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func saveBatchOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func replaceOperation(_: @escaping () throws -> [Model]) -> BaseOperation<Void> { ClosureOperation {} }
    func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { 0 } }
    func deleteAllOperation() -> BaseOperation<Void> { ClosureOperation {} }
}

final class CovHCrossChainChainRepository: CovHCrossChainEmptyRepository<ChainModel> {}

final class CovHCrossChainRuntimeRepository: CovHCrossChainEmptyRepository<fearless.RuntimeMetadataItem> {
    let fails: Bool

    init(fails: Bool) {
        self.fails = fails
    }

    override func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[fearless.RuntimeMetadataItem]> {
        guard fails else { return super.fetchAllOperation(with: options) }
        return ClosureOperation { throw CovHSendError.failed }
    }
}
