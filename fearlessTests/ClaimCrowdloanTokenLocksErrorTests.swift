import XCTest
import RobinHood
import SSFModels
@testable import fearless

/// ClaimCrowdloanRewardsInteractor.fetchTokenLocks reported both "no account" and "this asset has no currency id"
/// through didReceiveBalanceLocksError. Both outputs only log, so the screen looked the same; the token-lock problem
/// was logged as a balance-lock error, and a plain asset logged a missing account it did not have.
final class ClaimCrowdloanTokenLocksErrorTests: XCTestCase {
    func testAMissingAccountIsReportedOnceForEachKindOfLock() {
        let (interactor, output, performer) = makeInteractor(
            wallet: CovJFinClaimFixture.walletWithoutAccounts(),
            chainAsset: CovJFinClaimFixture.ormlChainAsset()
        )

        interactor.setup(with: output)
        CovJWait.drain()

        XCTAssertEqual(output.balanceLockErrors.map { $0 as? ChainAccountFetchingError }, [.accountNotExists])
        XCTAssertEqual(output.tokenLockErrors.map { $0 as? ChainAccountFetchingError }, [.accountNotExists])
        XCTAssertTrue(performer.paths.isEmpty)
    }

    func testAnAssetWithoutTokenLocksReportsNoError() throws {
        let (interactor, output, performer) = makeInteractor(
            wallet: AccountGenerator.generateMetaAccount(),
            chainAsset: CovJFinClaimFixture.plainChainAsset()
        )
        performer.balanceLocks = .success(try CovJFinClaimFixture.balanceLocks([("vesting ", 10)]))

        interactor.setup(with: output)
        XCTAssertTrue(CovJWait.until { output.balanceLocks.count == 1 && output.accountInfos.count == 1 })
        CovJWait.drain()

        XCTAssertTrue(output.balanceLockErrors.isEmpty, "\(output.balanceLockErrors)")
        XCTAssertTrue(output.tokenLockErrors.isEmpty)
        XCTAssertEqual(performer.paths, [.balanceLocks])
    }

    private func makeInteractor(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> (ClaimCrowdloanRewardsInteractor, CovJFinClaimInteractorOutput, CovJFinStoragePerformer) {
        let performer = CovJFinStoragePerformer()
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
            feeProxy: CovJFinFeeProxy(),
            extrinsicService: CovJFinExtrinsicService(),
            signer: CovJFinSigner(),
            chainRegistry: CovJFinChainRegistry(),
            storageRequestPerformer: performer,
            accountInfoFetcher: CovJFinAccountInfoFetcher()
        )
        return (interactor, CovJFinClaimInteractorOutput(), performer)
    }
}
