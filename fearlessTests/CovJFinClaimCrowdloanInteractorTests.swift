import XCTest
import BigInt
import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels
import SSFRuntimeCodingService
@testable import fearless

/// Runtime provider without a snapshot: call factories built on it report `metadataUnavailable`.
final class CovJFinRuntimeProvider: RuntimeProviderProtocol {
    var snapshot: RuntimeSnapshot? { nil }
    var runtimeSpecVersion: RuntimeSpecVersion { .defaultVersion }

    func setup() {}
    func cleanup() {}
    func setupHot() {}
    func readySnapshot() async throws -> RuntimeSnapshot { throw CovJError("no snapshot") }
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { throw CovJError("no coder factory") }
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol { throw CovJError("no coder factory") }
}

/// Storage performer answering balance and token lock requests; records the requests it saw.
final class CovJFinStoragePerformer: StorageRequestPerformer {
    var balanceLocks: Result<BalanceLocks?, Error> = .success(nil)
    var tokenLocks: Result<TokenLocks?, Error> = .success(nil)
    private let lock = NSLock()
    private var recorded: [(path: fearless.StorageCodingPath, accountId: Data?)] = []

    var paths: [fearless.StorageCodingPath] {
        lock.lock()
        defer { lock.unlock() }
        return recorded.map(\.path)
    }

    var accountIds: [Data?] {
        lock.lock()
        defer { lock.unlock() }
        return recorded.map(\.accountId)
    }

    private func record(_ request: StorageRequest) {
        let accountId = (request as? BalancesLocksRequest)?.accountId ?? (request as? TokensLocksRequest)?.accountId
        lock.lock()
        recorded.append((request.storagePath, accountId))
        lock.unlock()
    }

    func performSingle<T: Decodable>(_ request: StorageRequest) async throws -> T? {
        record(request)
        switch request.storagePath {
        case .balanceLocks:
            return try balanceLocks.get() as? T
        case .tokensLocks:
            return try tokenLocks.get() as? T
        default:
            throw CovJError("unexpected storage path")
        }
    }

    func performSingle<T: Decodable>(
        _: StorageRequest,
        withCacheOptions _: CachedStorageRequestTrigger
    ) async -> AsyncThrowingStream<T?, Error> {
        AsyncThrowingStream { $0.finish(throwing: CovJError("unsupported")) }
    }

    func performMultiple<T: Decodable>(_: MultipleRequest) async throws -> [T?] { throw CovJError("unsupported") }

    func performMultiple<T: Decodable>(
        _: MultipleRequest,
        withCacheOptions _: CachedStorageRequestTrigger
    ) async -> AsyncThrowingStream<[T?], Error> {
        AsyncThrowingStream { $0.finish(throwing: CovJError("unsupported")) }
    }

    func performPrefix<T: Decodable, K: Decodable & ScaleCodable>(_: PrefixRequest) async throws -> [K: T]? {
        throw CovJError("unsupported")
    }
}

/// Account info fetcher answering with `accountInfo` synchronously.
final class CovJFinAccountInfoFetcher: AccountInfoFetchingProtocol {
    var accountInfo: AccountInfo?
    private(set) var requestedAccountIds: [Data] = []

    func fetch(for chainAsset: ChainAsset, accountId: AccountId, completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void) {
        requestedAccountIds.append(accountId)
        completionBlock(chainAsset, accountInfo)
    }

    func fetch(for chainAssets: [ChainAsset], wallet _: MetaAccountModel, completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void) {
        completionBlock(Dictionary(uniqueKeysWithValues: chainAssets.map { ($0, accountInfo) }))
    }

    func fetch(for chainAsset: ChainAsset, accountId _: AccountId) async throws -> (ChainAsset, AccountInfo?) {
        (chainAsset, accountInfo)
    }

    func fetch(for chainAssets: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAsset: AccountInfo?] {
        Dictionary(uniqueKeysWithValues: chainAssets.map { ($0, accountInfo) })
    }

    func fetchByUniqKey(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAssetKey: AccountInfo?] { [:] }
}

final class CovJFinFeeProxy: ExtrinsicFeeProxyProtocol {
    weak var delegate: ExtrinsicFeeProxyDelegate?
    private(set) var identifiers: [ExtrinsicFeeId] = []
    private(set) var closures: [ExtrinsicBuilderClosure] = []

    func estimateFee(using _: ExtrinsicServiceProtocol, reuseIdentifier: ExtrinsicFeeId, setupBy closure: @escaping ExtrinsicBuilderClosure) {
        identifiers.append(reuseIdentifier)
        closures.append(closure)
    }
}

/// Extrinsic service that completes every submission with `submitResult` and keeps the builder closures.
final class CovJFinExtrinsicService: ExtrinsicServiceProtocol {
    var submitResult: SubmitExtrinsicResult = .success("0x01")
    private(set) var submittedClosures: [ExtrinsicBuilderClosure] = []
    private(set) var signers: [SigningWrapperProtocol] = []
    private(set) var queues: [DispatchQueue] = []

    func estimateFee(_: @escaping ExtrinsicBuilderClosure, runningIn _: DispatchQueue, completion: @escaping EstimateFeeClosure) {
        completion(.failure(CovJError("unsupported")))
    }

    func estimateFee(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        runningIn _: DispatchQueue,
        numberOfExtrinsics _: Int,
        completion: @escaping EstimateFeeIndexedClosure
    ) {
        completion([])
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion: @escaping ExtrinsicSubmitClosure
    ) {
        submittedClosures.append(closure)
        signers.append(signer)
        queues.append(queue)
        completion(submitResult)
    }

    func submit(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        signer _: SigningWrapperProtocol,
        runningIn _: DispatchQueue,
        numberOfExtrinsics _: Int,
        completion: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        completion([])
    }

    func submitAndWatch(
        _: @escaping ExtrinsicBuilderClosure,
        signer _: SigningWrapperProtocol,
        runningIn _: DispatchQueue,
        completion: @escaping ExtrinsicSubmitAndWatchClosure
    ) {
        completion(.failure(CovJError("unsupported")), nil)
    }
}

final class CovJFinSigner: SigningWrapperProtocol {
    func sign(_: Data) throws -> IRSignatureProtocol { throw CovJError("lane J never signs") }
}

final class CovJFinClaimInteractorOutput: ClaimCrowdloanRewardsInteractorOutput {
    var balanceLocks: [[LockProtocol]?] = []
    var tokenLocks: [[LockProtocol]?] = []
    var balanceLockErrors: [Error] = []
    var tokenLockErrors: [Error] = []
    var fees: [String] = []
    var feeErrors: [Error] = []
    var txHashes: [String] = []
    var txErrors: [Error] = []
    var accountInfos: [AccountInfo?] = []

    func didReceiveBalanceLocks(_ balanceLocks: [LockProtocol]?) { self.balanceLocks.append(balanceLocks) }
    func didReceiveBalanceLocksError(_ error: Error) { balanceLockErrors.append(error) }
    func didReceiveTokenLocks(_ balanceLocks: [LockProtocol]?) { tokenLocks.append(balanceLocks) }
    func didReceiveTokenLocksError(_ error: Error) { tokenLockErrors.append(error) }
    func didReceiveFee(_ fee: RuntimeDispatchInfo) { fees.append(fee.fee) }
    func didReceiveFeeError(_ error: Error) { feeErrors.append(error) }
    func didReceiveTxHash(_ txHash: String) { txHashes.append(txHash) }
    func didReceiveTxError(_ error: Error) { txErrors.append(error) }
    func didReceiveAccountInfo(accountInfo: AccountInfo?) { accountInfos.append(accountInfo) }
}

enum CovJFinClaimFixture {
    static func idBytes(_ text: String) -> String {
        "[" + Array(text.utf8).map { "\"\($0)\"" }.joined(separator: ",") + "]"
    }

    static func balanceLocks(_ entries: [(String, Int)]) throws -> BalanceLocks {
        let items = entries.map { "{\"id\":\(idBytes($0.0)),\"amount\":\"\($0.1)\",\"reasons\":[\"All\"]}" }
        return try JSONDecoder().decode(BalanceLocks.self, from: Data("[\(items.joined(separator: ","))]".utf8))
    }

    static func tokenLocks(_ entries: [(String, Int)]) throws -> TokenLocks {
        let items = entries.map { "{\"id\":\(idBytes($0.0)),\"amount\":\"\($0.1)\"}" }
        return try JSONDecoder().decode(TokenLocks.self, from: Data("[\(items.joined(separator: ","))]".utf8))
    }

    static func accountInfo(free: BigUInt, frozen: BigUInt = 0) -> AccountInfo {
        AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: free, reserved: 0, frozen: frozen))
    }

    /// A chain asset whose token is an ORML asset, so it has a currency id.
    static func ormlChainAsset(paraId: String? = nil, precision: UInt16 = 12) -> ChainAsset {
        let asset = AssetModel(
            id: "orml-kar", name: "Karura", symbol: "kar", precision: precision, icon: nil, currencyId: "KAR",
            existentialDeposit: nil, color: "#FF0000", isUtility: true, isNative: true, staking: nil, purchaseProviders: nil,
            type: .ormlAsset, ethereumType: nil, priceProvider: nil, coingeckoPriceId: nil
        )
        let chain = CovJFixture.chain(name: "Karura", assets: [asset])
        return ChainAsset(chain: chain, asset: asset)
    }

    static func plainChainAsset() -> ChainAsset {
        let asset = CovJFixture.asset(id: "plain", symbol: "pln")
        return ChainAsset(chain: CovJFixture.chain(name: "Plain", assets: [asset]), asset: asset)
    }

    static func walletWithoutAccounts() -> MetaAccountModel {
        MetaAccountModel(
            metaId: UUID().uuidString, name: "Empty", substrateAccountId: nil, substrateCryptoType: 0, substratePublicKey: nil,
            ethereumAddress: nil, ethereumPublicKey: nil, chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: false,
            unusedChainIds: nil, selectedCurrency: Currency.defaultCurrency(), networkManagmentFilter: nil, assetsVisibility: [],
            hasBackup: false, favouriteChainIds: []
        )
    }
}

final class CovJFinClaimCrowdloanInteractorTests: XCTestCase {
    private struct CovJFinClaimParts {
        let interactor: ClaimCrowdloanRewardsInteractor
        let performer: CovJFinStoragePerformer
        let fetcher: CovJFinAccountInfoFetcher
        let feeProxy: CovJFinFeeProxy
        let extrinsicService: CovJFinExtrinsicService
        let signer: CovJFinSigner
        let output: CovJFinClaimInteractorOutput
    }

    private func makeParts(wallet: MetaAccountModel, chainAsset: ChainAsset) -> CovJFinClaimParts {
        let performer = CovJFinStoragePerformer()
        let fetcher = CovJFinAccountInfoFetcher()
        let feeProxy = CovJFinFeeProxy()
        let extrinsicService = CovJFinExtrinsicService()
        let signer = CovJFinSigner()
        let interactor = ClaimCrowdloanRewardsInteractor(
            callFactory: SubstrateCallFactoryDefault(runtimeService: CovJFinRuntimeProvider()),
            wallet: wallet,
            chainAsset: chainAsset,
            crowdloanOperationFactory: CrowdloanOperationFactory(
                requestOperationFactory: CovJFinStorageRequestFactory(),
                operationManager: OperationManager(operationQueue: OperationQueue()),
                chainRegistry: CovJFinChainRegistry()
            ),
            operationQueue: OperationQueue(),
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            signer: signer,
            chainRegistry: CovJFinChainRegistry(),
            storageRequestPerformer: performer,
            accountInfoFetcher: fetcher
        )
        return CovJFinClaimParts(
            interactor: interactor, performer: performer, fetcher: fetcher, feeProxy: feeProxy,
            extrinsicService: extrinsicService, signer: signer, output: CovJFinClaimInteractorOutput()
        )
    }

    private func builder() -> ExtrinsicBuilderProtocol {
        ExtrinsicBuilder(specVersion: 1, transactionVersion: 1, genesisHash: "0x00")
    }

    func testSetupLoadsBalanceLocksTokenLocksAndAccountInfo() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let parts = makeParts(wallet: wallet, chainAsset: CovJFinClaimFixture.ormlChainAsset())
        parts.performer.balanceLocks = .success(try CovJFinClaimFixture.balanceLocks([("vesting ", 700), ("staking ", 300)]))
        parts.performer.tokenLocks = .success(try CovJFinClaimFixture.tokenLocks([("ormlvest", 50)]))
        parts.fetcher.accountInfo = CovJFinClaimFixture.accountInfo(free: 900, frozen: 100)

        parts.interactor.setup(with: parts.output)

        XCTAssertTrue(CovJWait.until { parts.output.balanceLocks.count == 1 && parts.output.tokenLocks.count == 1 && parts.output.accountInfos.count == 1 })
        XCTAssertEqual(parts.output.balanceLocks.first??.map(\.lockType), ["vesting", "staking"])
        XCTAssertEqual(parts.output.balanceLocks.first??.map(\.amount), [700, 300])
        XCTAssertEqual(parts.output.tokenLocks.first??.map(\.lockType), ["ormlvest"])
        XCTAssertEqual(parts.output.accountInfos.first??.data.sendAvailable, 800)
        XCTAssertEqual(parts.performer.paths.count, 2)
        XCTAssertTrue(parts.performer.paths.contains(.balanceLocks))
        XCTAssertTrue(parts.performer.paths.contains(.tokensLocks))
        XCTAssertEqual(parts.performer.accountIds, [wallet.substrateAccountId, wallet.substrateAccountId])
        XCTAssertEqual(parts.fetcher.requestedAccountIds, [wallet.substrateAccountId].compactMap { $0 })
        XCTAssertTrue(parts.output.balanceLockErrors.isEmpty)
        XCTAssertTrue(parts.output.tokenLockErrors.isEmpty)
    }

    func testSetupReportsLockFailuresAndMissingAccountInfo() throws {
        let parts = makeParts(wallet: AccountGenerator.generateMetaAccount(), chainAsset: CovJFinClaimFixture.ormlChainAsset())
        parts.performer.balanceLocks = .failure(CovJError("balances down"))
        parts.performer.tokenLocks = .failure(CovJError("tokens down"))

        parts.interactor.setup(with: parts.output)

        XCTAssertTrue(CovJWait.until {
            parts.output.balanceLockErrors.count == 1 && parts.output.tokenLockErrors.count == 1 && parts.output.accountInfos.count == 1
        })
        XCTAssertEqual(parts.output.balanceLockErrors.first as? CovJError, CovJError("balances down"))
        XCTAssertEqual(parts.output.tokenLockErrors.first as? CovJError, CovJError("tokens down"))
        XCTAssertNil(parts.output.accountInfos.first ?? nil)
        XCTAssertTrue(parts.output.balanceLocks.isEmpty)
    }

    func testAssetWithoutCurrencyIdOnlyQueriesBalanceLocks() throws {
        let parts = makeParts(wallet: AccountGenerator.generateMetaAccount(), chainAsset: CovJFinClaimFixture.plainChainAsset())
        parts.performer.balanceLocks = .success(try CovJFinClaimFixture.balanceLocks([("vesting ", 10)]))

        parts.interactor.setup(with: parts.output)

        XCTAssertTrue(CovJWait.until { parts.output.balanceLocks.count == 1 && parts.output.accountInfos.count == 1 })
        CovJWait.drain()
        XCTAssertEqual(parts.performer.paths, [.balanceLocks])
        XCTAssertTrue(parts.output.tokenLocks.isEmpty)
        XCTAssertTrue(parts.output.tokenLockErrors.isEmpty)
    }

    func testWalletWithoutAccountReportsMissingAccountWithoutQueries() {
        let parts = makeParts(wallet: CovJFinClaimFixture.walletWithoutAccounts(), chainAsset: CovJFinClaimFixture.ormlChainAsset())

        parts.interactor.setup(with: parts.output)
        CovJWait.drain()

        XCTAssertFalse(parts.output.balanceLockErrors.isEmpty)
        XCTAssertTrue(parts.output.balanceLockErrors.allSatisfy { ($0 as? ChainAccountFetchingError) == .accountNotExists })
        XCTAssertEqual(parts.output.accountInfos.count, 1)
        XCTAssertNil(parts.output.accountInfos.first ?? nil)
        XCTAssertTrue(parts.performer.paths.isEmpty)
        XCTAssertTrue(parts.fetcher.requestedAccountIds.isEmpty)
    }

    func testEstimateFeeUsesVestingClaimAndForwardsProxyResults() throws {
        let parts = makeParts(wallet: AccountGenerator.generateMetaAccount(), chainAsset: CovJFinClaimFixture.ormlChainAsset())
        parts.interactor.setup(with: parts.output)
        XCTAssertTrue(parts.feeProxy.delegate === parts.interactor)

        parts.interactor.estimateFee()

        XCTAssertEqual(parts.feeProxy.identifiers, [SubstrateCallPath.vestingClaim.callName])
        let closure = try XCTUnwrap(parts.feeProxy.closures.first)
        XCTAssertThrowsError(try closure(builder())) { error in
            XCTAssertEqual(error as? SubstrateCallFactoryError, .metadataUnavailable)
        }

        parts.interactor.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 12_345)), for: "vesting")
        parts.interactor.didReceiveFee(result: .failure(CovJError("fee failed")), for: "vesting")
        XCTAssertEqual(parts.output.fees, ["12345"])
        XCTAssertEqual(parts.output.feeErrors.first as? CovJError, CovJError("fee failed"))
    }

    func testSubmitSignsOnMainQueueAndReportsHashOrError() throws {
        let parts = makeParts(wallet: AccountGenerator.generateMetaAccount(), chainAsset: CovJFinClaimFixture.ormlChainAsset())
        parts.interactor.setup(with: parts.output)
        parts.extrinsicService.submitResult = .success("0xabc")

        parts.interactor.submit()
        parts.extrinsicService.submitResult = .failure(CovJError("rejected"))
        parts.interactor.submit()

        XCTAssertEqual(parts.output.txHashes, ["0xabc"])
        XCTAssertEqual(parts.output.txErrors.first as? CovJError, CovJError("rejected"))
        XCTAssertTrue(parts.extrinsicService.signers.allSatisfy { $0 as AnyObject === parts.signer })
        XCTAssertTrue(parts.extrinsicService.queues.allSatisfy { $0 === DispatchQueue.main })
        let closure = try XCTUnwrap(parts.extrinsicService.submittedClosures.first)
        XCTAssertThrowsError(try closure(builder()))
    }
}
