@testable import fearless
import Foundation
import RobinHood
import SSFModels
import SSFUtils
import XCTest

final class CovGAccountFetchingTests: XCTestCase {
    private let fetcher = CovGAccountFetcher()
    private let manager = OperationManager()

    func testFetchAllReturnsRepositoryAccountsOnMainQueue() throws {
        let accounts = [AccountGenerator.generateMetaAccount(), AccountGenerator.generateMetaAccount()]
        let repository = AnyDataProviderRepository(CovGFetchRepository<MetaAccountModel>(result: .success(accounts)))
        let result: [MetaAccountModel] = try collect {
            self.fetcher.fetchAllMetaAccounts(from: repository, operationManager: self.manager, closure: $0)
        }
        XCTAssertEqual(result.map(\.metaId), accounts.map(\.metaId))
    }

    func testNativeAccountAndMetaAccountCanBeFoundByAddress() throws {
        let chain = try CovGOperationFixtures.chain()
        let account = AccountGenerator.generateMetaAccount()
        let native = try XCTUnwrap(account.fetch(for: chain.accountRequest()))
        let address = try XCTUnwrap(native.toAddress())
        let repository = AnyDataProviderRepository(CovGFetchRepository<MetaAccountModel>(result: .success([account])))
        let response: ChainAccountResponse? = try collect {
            self.fetcher.fetchChainAccount(chain: chain, address: address, from: repository, operationManager: self.manager, closure: $0)
        }
        XCTAssertEqual(response?.accountId, native.accountId)
        XCTAssertEqual(response?.walletId, account.metaId)
        let meta: MetaAccountModel? = try collect {
            self.fetcher.fetchMetaAccount(chain: chain, address: address, from: repository, operationManager: self.manager, closure: $0)
        }
        XCTAssertEqual(meta?.metaId, account.metaId)
    }

    func testFallbackChainAccountLookupPreservesIdentityAndTargetChain() throws {
        let chain = try CovGOperationFixtures.chain()
        let key = Data(repeating: 7, count: 32)
        let chainAccount = ChainAccountModel(chainId: "another-chain", accountId: key, publicKey: key, cryptoType: 255, ethereumBased: false)
        let meta = AccountGenerator.generateMetaAccount(with: [chainAccount])
        let address = try key.toAddress(using: .substrate(42))
        var result: Result<ChainAccountResponse?, Error>?
        XCTAssertTrue(fetcher.fetchChainAccountFor(meta: meta, chain: chain, address: address) { result = $0 })
        let response = try XCTUnwrap(XCTUnwrap(result).get())
        XCTAssertEqual(response.chainId, chain.chainId)
        XCTAssertEqual(response.accountId, key)
        XCTAssertEqual(response.publicKey, key)
        XCTAssertEqual(response.cryptoType, .sr25519)
        XCTAssertTrue(response.isChainAccount)
        let repository = AnyDataProviderRepository(CovGFetchRepository<MetaAccountModel>(result: .success([meta])))
        let found: MetaAccountModel? = try collect {
            self.fetcher.fetchMetaAccount(chain: chain, address: address, from: repository, operationManager: self.manager, closure: $0)
        }
        XCTAssertEqual(found?.metaId, meta.metaId)
    }

    func testChainAccountListIncludesCompatibleFallbackAndExcludesDuplicateAndEthereumAccounts() throws {
        let chain = try CovGOperationFixtures.chain()
        let same = ChainAccountModel(chainId: chain.chainId, accountId: Data(repeating: 1, count: 32), publicKey: Data(), cryptoType: 0, ethereumBased: false)
        let compatible = ChainAccountModel(chainId: "other", accountId: Data(repeating: 2, count: 32), publicKey: Data(), cryptoType: 0, ethereumBased: false)
        let incompatible = ChainAccountModel(chainId: "evm", accountId: Data(repeating: 3, count: 20), publicKey: Data(), cryptoType: 0, ethereumBased: true)
        let meta = AccountGenerator.generateMetaAccount(with: [same, compatible, incompatible])
        let repository = AnyDataProviderRepository(CovGFetchRepository<MetaAccountModel>(result: .success([meta])))
        let results: [ChainAccountResponse] = try collect {
            self.fetcher.fetchChainAccounts(chain: chain, from: repository, operationManager: self.manager, closure: $0)
        }
        XCTAssertEqual(Set(results.map(\.accountId)), [same.accountId, compatible.accountId])
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.chainId == chain.chainId })
    }

    func testUnknownAddressReportsAccountNotExists() throws {
        let chain = try CovGOperationFixtures.chain()
        let meta = AccountGenerator.generateMetaAccount()
        var response: Result<ChainAccountResponse?, Error>?
        XCTAssertFalse(fetcher.fetchChainAccountFor(meta: meta, chain: chain, address: "absent") { response = $0 })
        XCTAssertThrowsError(try XCTUnwrap(response).get()) { XCTAssertTrue($0 is ChainAccountFetchingError) }
        let repository = AnyDataProviderRepository(CovGFetchRepository<MetaAccountModel>(result: .success([meta])))
        XCTAssertThrowsError(try collect { (closure: @escaping (Result<MetaAccountModel?, Error>) -> Void) in
            self.fetcher.fetchMetaAccount(chain: chain, address: "absent", from: repository, operationManager: self.manager, closure: closure)
        }) { XCTAssertTrue($0 is ChainAccountFetchingError) }
    }

    func testFetchFailuresAndCancelledParentsReachEveryCallback() throws {
        let chain = try CovGOperationFixtures.chain()
        for result in [nil, .failure(NSError(domain: "CovG.account", code: 87))] as [Result<[MetaAccountModel], Error>?] {
            let repository = AnyDataProviderRepository(CovGFetchRepository<MetaAccountModel>(result: result))
            XCTAssertThrowsError(try collect { (closure: @escaping (Result<[MetaAccountModel], Error>) -> Void) in
                self.fetcher.fetchAllMetaAccounts(from: repository, operationManager: self.manager, closure: closure)
            })
            XCTAssertThrowsError(try collect { (closure: @escaping (Result<[ChainAccountResponse], Error>) -> Void) in
                self.fetcher.fetchChainAccounts(chain: chain, from: repository, operationManager: self.manager, closure: closure)
            })
            XCTAssertThrowsError(try collect { (closure: @escaping (Result<ChainAccountResponse?, Error>) -> Void) in
                self.fetcher.fetchChainAccount(chain: chain, address: "absent", from: repository, operationManager: self.manager, closure: closure)
            })
            XCTAssertThrowsError(try collect { (closure: @escaping (Result<MetaAccountModel?, Error>) -> Void) in
                self.fetcher.fetchMetaAccount(chain: chain, address: "absent", from: repository, operationManager: self.manager, closure: closure)
            })
        }
    }

    private func collect<T>(_ action: (@escaping (Result<T, Error>) -> Void) -> Void) throws -> T {
        let done = expectation(description: "main queue callback")
        var received: Result<T, Error>?
        action {
            XCTAssertTrue(Thread.isMainThread)
            received = $0
            done.fulfill()
        }
        wait(for: [done], timeout: 15)
        return try XCTUnwrap(received).get()
    }
}

private struct CovGAccountFetcher: AccountFetching {}

final class CovGFetchRepository<T: RobinHood.Identifiable>: DataProviderRepositoryProtocol {
    let result: Result<[T], Error>?
    let backing = InMemoryDataProviderRepository<T>()
    init(result: Result<[T], Error>?) {
        self.result = result
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        let operation = BaseOperation<[T]>()
        operation.result = result
        return operation
    }

    func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions) -> BaseOperation<[T]> {
        backing.fetchOperation(by: ids, options: options)
    }

    func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions) -> BaseOperation<T?> {
        backing.fetchOperation(by: id, options: options)
    }

    func fetchOperation(by _: RepositorySliceRequest, options: RepositoryFetchOptions) -> BaseOperation<[T]> {
        fetchAllOperation(with: options)
    }

    func saveOperation(_ update: @escaping () throws -> [T], _ delete: @escaping () throws -> [String]) -> BaseOperation<Void> {
        backing.saveOperation(update, delete)
    }

    func saveBatchOperation(_ update: @escaping () throws -> [T], _ delete: @escaping () throws -> [String]) -> BaseOperation<Void> {
        backing.saveBatchOperation(update, delete)
    }

    func replaceOperation(_ update: @escaping () throws -> [T]) -> BaseOperation<Void> {
        backing.replaceOperation(update)
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        backing.deleteAllOperation()
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        backing.fetchCountOperation()
    }
}
