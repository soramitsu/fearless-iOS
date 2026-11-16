import Foundation
import XCTest

@testable import fearless

final class CovDSwapExecutorStub: PolkaswapExtrinsicExecuting {
    var submissions = 0
    func estimateFee(_: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo { RuntimeDispatchInfo(feeValue: 23) }
    func submit(_: @escaping ExtrinsicBuilderClosure) async throws -> String {
        submissions += 1
        return "0xswap"
    }
}

final class CovDSwapAuthorizationStub: PolkaswapSubmissionAuthorizing {
    let executor = CovDSwapExecutorStub()
    var amounts: [Decimal] = []
    var guards = 0
    func authorize(params: PolkaswapPreviewParams) async throws -> PolkaswapAuthorizedSubmission {
        amounts.append(params.fromAmount)
        return PolkaswapAuthorizedSubmission(builder: { $0 }, executor: executor, finalGuard: { self.guards += 1 })
    }
}

final class CovDSwapResultSpy: PolkaswapSwapConfirmationInteractorOutput {
    var results: [Result<String, Error>] = []
    func didReceive(extrinsicResult: Result<String, Error>) { results.append(extrinsicResult) }
}

final class CovDExecutionAdapterTests: XCTestCase {
    func testAsyncExecutorsForwardFeesAndRequireMutationAuthorization() async throws {
        let wallet = CovDFixtures.wallet()
        let chain = CovDSwapFixtures.chain()
        let account = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
        let signer = SigningWrapper(keystore: KeystoreProtocolStub(), metaId: wallet.metaId, accountResponse: account)
        let service = ExtrinsicServiceStub(dispatchInfo: .success(RuntimeDispatchInfo(feeValue: 23)), txHash: .success("0xhash"))
        let demeter = DemeterMutationExtrinsicExecutor(service: service, signer: signer)
        let market = PolkamarktMutationExtrinsicExecutor(service: service, signer: signer)
        let swap = PolkaswapExtrinsicExecutor(service: service, signer: signer)
        let demeterFee = try await demeter.estimateFee { $0 }
        let marketFee = try await market.estimateFee { $0 }
        let swapFee = try await swap.estimateFee { $0 }
        XCTAssertEqual([demeterFee.fee, marketFee.fee, swapFee.fee], ["23", "23", "23"])
        let restricted: [() async throws -> String] = [
            { try await demeter.submit { $0 } }, { try await market.submit { $0 } }
        ]
        for submit in restricted {
            do {
                _ = try await submit()
                XCTFail("Expected authorization rejection")
            } catch { XCTAssertTrue(error is MutationAuthorizationError) }
        }
        let swapHash = try await swap.submit { $0 }
        XCTAssertEqual(swapHash, "0xhash")
    }

    func testAsyncExecutorsPreserveErrors() async throws {
        let wallet = CovDFixtures.wallet()
        let account = try XCTUnwrap(wallet.fetch(for: CovDSwapFixtures.chain().accountRequest()))
        let signer = SigningWrapper(keystore: KeystoreProtocolStub(), metaId: wallet.metaId, accountResponse: account)
        let service = ExtrinsicServiceStub(dispatchInfo: .failure(CovDTestError.offline), txHash: .failure(CovDTestError.offline))
        let demeter = DemeterMutationExtrinsicExecutor(service: service, signer: signer)
        let market = PolkamarktMutationExtrinsicExecutor(service: service, signer: signer)
        let swap = PolkaswapExtrinsicExecutor(service: service, signer: signer)
        let fees: [() async throws -> RuntimeDispatchInfo] = [
            { try await demeter.estimateFee { $0 } }, { try await market.estimateFee { $0 } }, { try await swap.estimateFee { $0 } }
        ]
        for fee in fees {
            do {
                _ = try await fee()
                XCTFail("Expected fee error")
            } catch { XCTAssertEqual(error as? CovDTestError, .offline) }
        }
        do {
            _ = try await swap.submit { $0 }
            XCTFail("Expected submission error")
        } catch { XCTAssertEqual(error as? CovDTestError, .offline) }
    }

    func testConfirmationUsesUpdatedParametersAndReturnsSubmittedHash() throws {
        let authorizer = CovDSwapAuthorizationStub()
        let output = CovDSwapResultSpy()
        let interactor = PolkaswapSwapConfirmationInteractor(
            params: CovDSwapFixtures.params(from: 1), submissionAuthorizer: authorizer,
            mutationsEnabled: { true }, disclaimerAccepted: { true }
        )
        interactor.setup(with: output)
        interactor.update(params: CovDSwapFixtures.params(from: 3))
        interactor.submit()
        XCTAssertTrue(CovDFixtures.spin { output.results.count == 1 })
        XCTAssertEqual(authorizer.amounts, [3])
        XCTAssertEqual(authorizer.guards, 1)
        XCTAssertEqual(authorizer.executor.submissions, 1)
        XCTAssertEqual(try output.results.first?.get(), "0xswap")
    }
}
