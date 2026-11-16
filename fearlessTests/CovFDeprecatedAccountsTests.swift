import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

final class CovFDeprecatedAccountsTests: XCTestCase {
    func testStashRecordsAreReturnedAndRepositoryErrorsPropagate() async throws {
        let fixture = try CovFDeprecatedFixture()
        let item = StashItem(stash: "stash", controller: "controller")
        fixture.stashes.items = [item]
        let result = try await fixture.service.checkStashItems()
        XCTAssertEqual(result, [item])
        fixture.stashes.failure = NSError(domain: "stash", code: 7)
        do {
            _ = try await fixture.service.checkStashItems()
            XCTFail("Repository failure must propagate")
        } catch { XCTAssertEqual((error as NSError).domain, "stash") }
    }

    func testEmptyAndFailedChainCatalogHaveNoDeprecationIssue() async throws {
        let fixture = try CovFDeprecatedFixture()
        fixture.chains.items = []
        let empty = try await fixture.service.checkAccountDeprecations(wallet: fixture.wallet)
        XCTAssertNil(empty)
        fixture.chains.failure = NSError(domain: "catalog", code: 8)
        let unavailable = try await fixture.service.checkAccountDeprecations(wallet: fixture.wallet)
        XCTAssertNil(unavailable)
    }

    func testMissingAndFailingRuntimeThrowProviderUnavailable() async throws {
        let fixture = try CovFDeprecatedFixture()
        for available in [false, true] {
            fixture.registry.runtime = available ? fixture.runtime : nil
            fixture.runtime.failure = NSError(domain: "metadata", code: 9)
            do {
                _ = try await fixture.service.checkAccountDeprecations(wallet: fixture.wallet)
                XCTFail("Staking chain requires metadata")
            } catch {
                XCTAssertTrue(error is fearless.RuntimeProviderError)
            }
        }
    }

    func testRuntimeStillAcceptingControllerDoesNotQueryAccounts() async throws {
        let fixture = try CovFDeprecatedFixture(deprecated: false)
        let issue = try await fixture.service.checkAccountDeprecations(wallet: fixture.wallet)
        XCTAssertNil(issue)
        XCTAssertTrue(fixture.storage.requestedPaths.isEmpty)
    }

    func testDeprecatedControllerReturnsIssueForSelectedWallet() async throws {
        let fixture = try CovFDeprecatedFixture()
        let controller = Data(repeating: 2, count: 32)
        try fixture.storage.put(.controller, value: controller.base64EncodedString())
        let issue = try await fixture.service.checkAccountDeprecations(wallet: fixture.wallet)
        guard case let .controller(value) = issue else { return XCTFail("Expected controller issue") }
        XCTAssertEqual(value.wallet, fixture.wallet)
        XCTAssertEqual(value.chainAsset, fixture.asset)
        XCTAssertEqual(value.address, try AddressFactory.address(for: controller, chain: fixture.asset.chain))
    }

    func testOwnControllerAndOwnStashAreNotDeprecated() async throws {
        let fixture = try CovFDeprecatedFixture()
        let account = try XCTUnwrap(fixture.wallet.fetch(for: fixture.asset.chain.accountRequest())?.accountId)
        try fixture.storage.put(.controller, value: account.base64EncodedString())
        try fixture.putLedger(stash: account)
        let issue = try await fixture.service.checkAccountDeprecations(wallet: fixture.wallet)
        XCTAssertNil(issue)
        XCTAssertEqual(Set(fixture.storage.requestedPaths.map(\.itemName)), ["Bonded", "Ledger"])
    }

    func testUnknownStashReturnsAddressForImport() async throws {
        let fixture = try CovFDeprecatedFixture()
        let stash = Data(repeating: 3, count: 32)
        try fixture.putLedger(stash: stash)
        let issue = try await fixture.service.checkAccountDeprecations(wallet: fixture.wallet)
        guard case let .stash(address) = issue else { return XCTFail("Expected stash issue") }
        XCTAssertEqual(address, try AddressFactory.address(for: stash, chain: fixture.asset.chain))
    }

    func testKnownStashReturnsControllerIssueForOwningWallet() async throws {
        let fixture = try CovFDeprecatedFixture()
        let owner = AccountGenerator.generateMetaAccount()
        let stash = try XCTUnwrap(owner.fetch(for: fixture.asset.chain.accountRequest())?.accountId)
        fixture.wallets.items = [owner]
        try fixture.putLedger(stash: stash)
        let issue = try await fixture.service.checkAccountDeprecations(wallet: fixture.wallet)
        guard case let .controller(value) = issue else { return XCTFail("Expected known stash wallet") }
        XCTAssertEqual(value.wallet, owner)
        XCTAssertEqual(value.address, try AddressFactory.address(for: stash, chain: fixture.asset.chain))
    }

    func testMissingConnectionAndMalformedStorageDoNotInventIssues() async throws {
        let fixture = try CovFDeprecatedFixture()
        fixture.registry.connection = nil
        let disconnected = try await fixture.service.checkAccountDeprecations(wallet: fixture.wallet)
        XCTAssertNil(disconnected)
        fixture.registry.connection = MockConnection()
        try fixture.storage.put(.controller, value: ["invalid": "data"])
        try fixture.storage.put(.stakingLedger, value: ["invalid": "data"])
        let malformed = try await fixture.service.checkAccountDeprecations(wallet: fixture.wallet)
        XCTAssertNil(malformed)
    }
}

private final class CovFDeprecatedFixture {
    let asset = CovFFixtures.asset()
    let wallet = AccountGenerator.generateMetaAccount()
    let chains = CovFRepository<ChainModel>()
    let wallets = CovFRepository<MetaAccountModel>()
    let stashes = CovFRepository<StashItem>()
    let registry = CovFRegistry()
    let storage = CovFStorageRequests()
    let runtime: CovFRuntime
    let queue = OperationQueue()
    lazy var service = DeprecatedControllerStashAccountCheckService(
        chainRegistry: registry, chainRepository: AnyDataProviderRepository(chains), storageRequestFactory: storage,
        operationQueue: queue, walletRepository: AnyDataProviderRepository(wallets), stashItemRepository: AnyDataProviderRepository(stashes)
    )

    init(deprecated: Bool = true) throws {
        let arguments: [RuntimeMetadataV1.FunctionArgumentMetadata] = deprecated ? [] : [.init(name: "controller", type: "AccountId")]
        let module = RuntimeMetadataV1.ModuleMetadata(
            name: "Staking", storage: nil,
            calls: [.init(name: "set_controller", arguments: arguments, documentation: [])],
            events: nil, constants: [], errors: [], index: 0
        )
        let metadata = try RuntimeMetadata.v1(modules: [module], extrinsic: .init(version: 4, signedExtensions: []))
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(Data(#"{"types":{}}"#.utf8), runtimeMetadata: metadata, usedRuntimePaths: [:])
        runtime = CovFRuntime(factory: TestRuntimeCoderFactory(catalog: catalog, specVersion: 1, txVersion: 1, metadata: metadata))
        registry.runtime = runtime
        registry.connection = MockConnection()
        chains.items = [asset.chain]
        queue.maxConcurrentOperationCount = 1
    }

    func putLedger(stash: Data) throws {
        try storage.put(.stakingLedger, value: [
            "stash": stash.base64EncodedString(), "total": "100", "active": "100", "unlocking": [], "claimedRewards": []
        ])
    }
}
