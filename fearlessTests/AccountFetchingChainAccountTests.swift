import RobinHood
import SSFModels
import XCTest
@testable import fearless

/// `fetchChainAccount` answers once: with the account that owns the address, or with `accountNotExists`. It used to
/// answer `accountNotExists` for every wallet before the owner and then again with the owner, and not at all when
/// there were no wallets.
final class AccountFetchingChainAccountTests: XCTestCase {
    private let probe = AccountFetchingProbe()

    func testLookupAnswersOnceWithTheWalletThatOwnsTheAddress() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)
        let owner = AccountGenerator.generateMetaAccount()
        let wallets = [AccountGenerator.generateMetaAccount(), AccountGenerator.generateMetaAccount(), owner]
        let address = try XCTUnwrap(owner.fetch(for: chain.accountRequest())?.toAddress())

        let results = try lookUp(address, on: chain, in: wallets)

        XCTAssertEqual(results.count, 1, "one answer")
        let account = try XCTUnwrap(try results.first?.get())
        XCTAssertEqual(account.accountId, owner.substrateAccountId)
    }

    func testLookupWithoutWalletsAnswersThatNoAccountOwnsTheAddress() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)

        let results = try lookUp("5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY", on: chain, in: [])

        XCTAssertEqual(results.count, 1)
        XCTAssertThrowsError(try results.first?.get()) { error in
            guard case ChainAccountFetchingError.accountNotExists = error else { return XCTFail("unexpected \(error)") }
        }
    }

    func testLookupForAnAddressNoWalletOwnsAnswersOnce() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)
        let wallets = [AccountGenerator.generateMetaAccount(), AccountGenerator.generateMetaAccount()]

        let results = try lookUp("5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY", on: chain, in: wallets)

        XCTAssertEqual(results.count, 1)
        XCTAssertThrowsError(try results.first?.get())
    }

    private func lookUp(
        _ address: String,
        on chain: ChainModel,
        in wallets: [fearless.MetaAccountModel]
    ) throws -> [Result<ChainAccountResponse?, Error>] {
        var results: [Result<ChainAccountResponse?, Error>] = []
        let answered = XCTestExpectation(description: "the lookup answers")
        answered.assertForOverFulfill = false
        probe.fetchChainAccount(
            chain: chain,
            address: address,
            from: AnyDataProviderRepository(StaticWalletRepository(wallets: wallets)),
            operationManager: OperationManager()
        ) { result in
            results.append(result)
            answered.fulfill()
        }
        XCTAssertEqual(XCTWaiter.wait(for: [answered], timeout: 10), .completed)
        // Every answer is given from the same main-queue block; let any later block run before counting.
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        return results
    }
}

private final class AccountFetchingProbe: AccountFetching {}

private struct StaticWalletRepository: DataProviderRepositoryProtocol {
    typealias Model = fearless.MetaAccountModel
    let wallets: [fearless.MetaAccountModel]

    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { wallets }
    }

    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<Model?> {
        ClosureOperation { wallets.first }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { wallets }
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { wallets }
    }

    func saveOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func saveBatchOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func replaceOperation(_: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { wallets.count }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { () }
    }
}
