import SSFUtils
import Foundation
import RobinHood
import SSFModels
import TonAPI
import TonSwift
import XCTest
@testable import fearless

final class TonHistoryOperationFactoryTests: XCTestCase {
    private static let owner = "0:" + String(repeating: "11", count: 32)
    private static let peer = "0:" + String(repeating: "22", count: 32)
    private static let master = "0:" + String(repeating: "33", count: 32)
    private static let ownerJetton = "0:" + String(repeating: "44", count: 32)
    private static let peerJetton = "0:" + String(repeating: "55", count: 32)
    private static let native = AssetModel(id: "TON", name: "Toncoin", symbol: "TON", precision: 9, isUtility: true, isNative: true)

    func testAssemblyRestoresTonHistoryForLegacyAndCurrentChains() {
        let storage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()
        for id in ["-239", "-3", "ton:mainnet", "ton-mainnet"] {
            XCTAssertTrue(HistoryOperationFactoriesAssembly.createOperationFactory(
                chain: Self.chain(id: id), txStorage: AnyDataProviderRepository(storage)
            ) is TonHistoryOperationFactory)
        }
    }

    func testRestoredHistoryUsesSameIdentityForAllFriendlyAddressEncodings() throws {
        let event = try Self.event(actions: [Self.tonAction()])
        for address in [Self.owner,
                        try TonSwift.Address.parse(Self.owner).toFriendly(bounceable: true).toString(),
                        try TonSwift.Address.parse(Self.owner).toFriendly(bounceable: false).toString()] {
            let remote = TestTonHistoryRemote(response: .init(events: [event], next_from: 100))
            let page = try execute(remote: remote, address: address)
            XCTAssertEqual(remote.address, Self.owner)
            XCTAssertEqual(page.transactions.count, 1)
            let tx = try XCTUnwrap(page.transactions.first)
            XCTAssertEqual(tx.type, TransactionType.outgoing.rawValue)
            XCTAssertEqual(tx.amount.decimalValue, 2)
            XCTAssertEqual(tx.status, .commited)
            XCTAssertEqual(tx.transactionId, "history-event")
            XCTAssertEqual(tx.assetId, "TON")
            XCTAssertEqual(tx.details, "legacy memo")
            XCTAssertEqual(tx.fees.first?.assetId, "TON")
            XCTAssertEqual(tx.fees.first?.amount.decimalValue, Decimal(string: "0.001"))
            XCTAssertEqual(page.context?["nextFrom"], "100")
        }
    }

    func testIncomingPendingAndFailedHistoryRemainVisible() throws {
        let incoming = try Self.event(actions: [Self.tonAction(incoming: true)], pending: true)
        let failed = try Self.event(actions: [Self.tonAction(status: "failed")])
        let remote = TestTonHistoryRemote(response: .init(events: [incoming, failed], next_from: 0))
        let page = try execute(remote: remote)
        XCTAssertEqual(page.transactions.count, 2)
        XCTAssertTrue(page.transactions.contains { $0.status == .pending && $0.type == TransactionType.incoming.rawValue && $0.fees.isEmpty })
        XCTAssertTrue(page.transactions.contains { $0.status == .rejected })
        XCTAssertNil(page.context)
    }

    func testJettonHistoryPreservesLegacyWalletAndCurrentMasterIdentifiersWithoutBalanceLookup() throws {
        let event = try Self.event(actions: [Self.jettonAction()])
        for id in [Self.master, Self.ownerJetton,
                   try TonSwift.Address.parse(Self.ownerJetton).toFriendly(bounceable: false).toString()] {
            let remote = TestTonHistoryRemote(response: .init(events: [event], next_from: 0))
            let page = try execute(remote: remote, asset: Self.jetton(id: id))
            XCTAssertEqual(page.transactions.count, 1)
            XCTAssertEqual(page.transactions.first?.amount.decimalValue, Decimal(string: "123.456789"))
            XCTAssertEqual(page.transactions.first?.fees.first?.assetId, "TON")
            XCTAssertEqual(page.transactions.first?.fees.first?.amount.decimalValue, Decimal(string: "0.001"))
        }
        let unrelated = TestTonHistoryRemote(response: .init(events: [event], next_from: 0))
        XCTAssertTrue(try execute(remote: unrelated, asset: Self.jetton(id: Self.peerJetton)).transactions.isEmpty)
    }

    func testIncomingLegacyJettonHistoryUsesOwnerWalletAndSenderPeer() throws {
        let event = try Self.event(actions: [Self.jettonAction(incoming: true)])
        let remote = TestTonHistoryRemote(response: .init(events: [event], next_from: 0))
        let page = try execute(remote: remote, asset: Self.jetton(id: Self.ownerJetton))
        XCTAssertEqual(page.transactions.first?.type, TransactionType.incoming.rawValue)
        XCTAssertEqual(page.transactions.first?.peerId, try TonSwift.Address.parse(Self.peer).toFriendly(bounceable: false).toString())
        XCTAssertTrue(try XCTUnwrap(page.transactions.first).fees.isEmpty)
    }

    func testPaginationAdvancesAcrossUnrelatedActionsAndHonorsBound() throws {
        let remote = TestTonHistoryRemote(response: .init(events: [try Self.event(actions: [Self.jettonAction()])], next_from: 100))
        let page = try execute(remote: remote, pagination: Pagination(count: 500, context: ["nextFrom": "200"]))
        XCTAssertTrue(page.transactions.isEmpty)
        XCTAssertEqual(page.context?["nextFrom"], "100")
        XCTAssertEqual(remote.before, 200)
        XCTAssertEqual(remote.limit, 100)
        remote.response.next_from = 200
        XCTAssertNil(try execute(remote: remote, pagination: Pagination(count: 5, context: ["nextFrom": "200"])).context)
    }

    func testInvalidCursorNeverStartsNetworkAndTransportFailureCanRetry() throws {
        let remote = TestTonHistoryRemote(response: .init(events: [try Self.event(actions: [Self.tonAction()])], next_from: 0))
        for cursor in ["invalid", "-1", "0", "9223372036854775808"] {
            XCTAssertThrowsError(try execute(remote: remote, pagination: Pagination(count: 10, context: ["nextFrom": cursor])))
        }
        XCTAssertEqual(remote.calls, 0)
        remote.fail = true
        XCTAssertThrowsError(try execute(remote: remote))
        remote.fail = false
        XCTAssertEqual(try execute(remote: remote).transactions.count, 1)
    }

    func testMalformedAmountsAndForeignAccountsDoNotReplaceValidHistory() throws {
        let remote = TestTonHistoryRemote(response: .init(events: [try Self.event(actions: [Self.jettonAction(amount: "invalid")])], next_from: 0))
        XCTAssertTrue(try execute(remote: remote, asset: Self.jetton(id: Self.master)).transactions.isEmpty)
        remote.response.events[0].account.address = Self.peer
        XCTAssertThrowsError(try execute(remote: remote))
        remote.response = .init(events: [try Self.event(actions: [Self.tonAction()], extra: Int64.min)], next_from: 0)
        XCTAssertEqual(try execute(remote: remote).transactions.count, 1)
    }

    func testFiltersAndUnsupportedChainsProduceNoTransfers() throws {
        let remote = TestTonHistoryRemote(response: .init(events: [try Self.event(actions: [Self.tonAction()])], next_from: 0))
        XCTAssertTrue(try execute(remote: remote, filters: [.init(type: .reward, selected: true)]).transactions.isEmpty)
        XCTAssertTrue(try execute(remote: remote, pagination: Pagination(count: 0)).transactions.isEmpty)
    }

    func testRemoteClientUsesInjectedTransportAndEncodedAccountCursor() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestTonHistoryURLProtocol.self]
        let fixture = try JSONEncoder().encode(Components.Schemas.AccountEvents(events: [try Self.event(actions: [Self.tonAction()])], next_from: 100))
        TestTonHistoryURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "tonapi.io")
            XCTAssertTrue(request.url?.path.hasSuffix("/events") == true)
            let query = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertTrue(query.contains(URLQueryItem(name: "before_lt", value: "200")))
            XCTAssertTrue(query.contains(URLQueryItem(name: "limit", value: "25")))
            return fixture
        }
        defer { TestTonHistoryURLProtocol.handler = nil }
        let remote = TonHistoryRemoteClient(clientProvider: { chain in
            XCTAssertEqual(chain.chainId, "-239")
            return TonAPIClientFactory(tonAPIURL: URL(string: "https://tonapi.io")!, token: "").tonAPIClient(configuration: configuration)
        })
        let response = try await remote.events(address: Self.owner, chain: Self.chain(), before: 200, limit: 25)
        XCTAssertEqual(response.events.count, 1)
        XCTAssertEqual(response.next_from, 100)
    }

    private func execute(
        remote: TestTonHistoryRemote, address: String = owner,
        asset: AssetModel = native, filters: [WalletTransactionHistoryFilter] = [],
        pagination: Pagination = Pagination(count: 25)
    ) throws -> AssetTransactionPageData {
        let wrapper = TonHistoryOperationFactory(remote: remote).fetchTransactionHistoryOperation(
            asset: asset, chain: Self.chain(), address: address, filters: filters, pagination: pagination
        )
        let done = expectation(description: "TON history")
        wrapper.targetOperation.completionBlock = { done.fulfill() }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [done], timeout: 10)
        let result: AssetTransactionPageData? = try wrapper.targetOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
        return try XCTUnwrap(result)
    }

    private static func chain(id: String = "-239") -> ChainModel {
        ChainModel(
            rank: nil, disabled: false, chainId: id, parentId: nil, paraId: nil, name: "TON",
            assets: [native], xcm: nil,
            nodes: [.init(url: URL(string: "https://tonapi.io")!, name: "TON", apikey: nil)],
            addressPrefix: 0, icon: nil, options: nil, externalApi: nil, customNodes: nil,
            iosMinAppVersion: nil, identityChain: nil
        )
    }

    private static func jetton(id: String) -> AssetModel {
        AssetModel(id: id, name: "Legacy token", symbol: "JET", precision: 6, isUtility: false, isNative: false)
    }

    private static func account(_ address: String) -> [String: Any] {
        ["address": address, "is_scam": false, "is_wallet": true]
    }

    private static func tonAction(incoming: Bool = false, status: String = "ok") -> [String: Any] {
        ["type": "TonTransfer", "status": status,
         "TonTransfer": ["sender": account(incoming ? peer : owner), "recipient": account(incoming ? owner : peer),
                         "amount": 2_000_000_000, "comment": "legacy memo"],
         "simple_preview": ["name": "Transfer", "description": "Fixture", "accounts": []]]
    }

    private static func jettonAction(incoming: Bool = false, amount: String = "123456789") -> [String: Any] {
        ["type": "JettonTransfer", "status": "ok",
         "JettonTransfer": ["sender": account(incoming ? peer : owner), "recipient": account(incoming ? owner : peer),
                            "senders_wallet": incoming ? peerJetton : ownerJetton,
                            "recipients_wallet": incoming ? ownerJetton : peerJetton, "amount": amount,
                            "jetton": ["address": master, "name": "Token", "symbol": "JET", "decimals": 6, "image": "https://example.org/token.png", "verification": "whitelist"]],
         "simple_preview": ["name": "Transfer", "description": "Fixture", "accounts": []]]
    }

    private static func event(actions: [[String: Any]], pending: Bool = false, extra: Int64 = -1_000_000) throws -> Components.Schemas.AccountEvent {
        let json: [String: Any] = [
            "event_id": "history-event", "account": account(owner), "timestamp": 1_720_000_000,
            "actions": actions, "is_scam": false, "lt": 201, "in_progress": pending, "extra": extra
        ]
        return try JSONDecoder().decode(Components.Schemas.AccountEvent.self, from: JSONSerialization.data(withJSONObject: json))
    }
}

private final class TestTonHistoryRemote: TonHistoryRemoteProtocol {
    var response: Components.Schemas.AccountEvents
    var fail = false
    var resolvedMaster: String?
    var failMasterLookup = false
    var masterLookups = 0
    var lookupOwner: String?
    var lookupWallet: String?
    func jettonMaster(walletAddress: String, owner: String, chain: ChainModel) async throws -> String? {
        masterLookups += 1
        lookupWallet = walletAddress
        lookupOwner = owner
        if failMasterLookup { throw URLError(.notConnectedToInternet) }
        return resolvedMaster
    }
    var calls = 0
    var address: String?
    var before: Int64?
    var limit: Int?
    init(response: Components.Schemas.AccountEvents) { self.response = response }
    func events(address: String, chain _: ChainModel, before: Int64?, limit: Int) async throws -> Components.Schemas.AccountEvents {
        calls += 1
        self.address = address
        self.before = before
        self.limit = limit
        if fail { throw URLError(.notConnectedToInternet) }
        return response
    }
}

private final class TestTonHistoryURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> Data)?
    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let data = try Self.handler?(request) ?? Data()
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}


extension TonHistoryOperationFactoryTests {
    private static var outputMaster: String { "0:" + String(repeating: "66", count: 32) }

    private static func swapAction(user: String = owner, nativeInput: Bool = false, status: String = "ok") -> [String: Any] {
        func preview(_ address: String, _ symbol: String, _ decimals: Int) -> [String: Any] {
            ["address": address, "name": symbol, "symbol": symbol, "decimals": decimals,
             "image": "https://example.org/token.png", "verification": "whitelist"]
        }
        var swap: [String: Any] = [
            "dex": "fixture", "amount_in": "1250000", "amount_out": "3500000000",
            "user_wallet": account(user), "router": account(peer),
            "jetton_master_out": preview(outputMaster, "OUT", 9)
        ]
        if nativeInput { swap["ton_in"] = 2_000_000_000 }
        else { swap["jetton_master_in"] = preview(master, "JET", 6) }
        return ["type": "JettonSwap", "status": status, "JettonSwap": swap,
                "simple_preview": ["name": "Swap", "description": "Fixture", "accounts": []]]
    }

    func testJettonSwapHistoryKeepsBothAmountsPrecisionTimeAndTonFee() throws {
        let event = try Self.event(actions: [Self.swapAction()])
        let remote = TestTonHistoryRemote(response: .init(events: [event], next_from: 100))
        let page = try execute(remote: remote, asset: Self.jetton(id: Self.master), filters: [.init(type: .swap, selected: true)])
        let transaction = try XCTUnwrap(page.transactions.first)
        XCTAssertEqual(transaction.type, TransactionType.swap.rawValue)
        XCTAssertEqual(transaction.amount.decimalValue, Decimal(string: "3.5"))
        XCTAssertEqual(Decimal(string: transaction.details), Decimal(string: "1.25"))
        XCTAssertEqual(transaction.assetId, Self.outputMaster)
        XCTAssertEqual(transaction.peerId, Self.master)
        XCTAssertEqual(transaction.timestamp, 1_720_000_000)
        XCTAssertEqual(transaction.fees.first?.assetId, Self.native.id)
        XCTAssertEqual(transaction.fees.first?.amount.decimalValue, Decimal(string: "0.001"))
        XCTAssertEqual(remote.masterLookups, 0)
        XCTAssertTrue(try execute(remote: remote, asset: Self.jetton(id: Self.master), filters: [.init(type: .transfer, selected: true)]).transactions.isEmpty)
    }

    func testZeroBalanceLegacyWalletIdResolvesOnlyItsOwnersMasterForSwaps() throws {
        let event = try Self.event(actions: [Self.swapAction()])
        let remote = TestTonHistoryRemote(response: .init(events: [event], next_from: 100))
        remote.resolvedMaster = Self.master
        let page = try execute(remote: remote, asset: Self.jetton(id: Self.ownerJetton))
        XCTAssertEqual(page.transactions.count, 1)
        XCTAssertEqual(remote.masterLookups, 1)
        XCTAssertEqual(remote.lookupOwner, Self.owner)
        XCTAssertEqual(remote.lookupWallet, Self.ownerJetton)
        remote.resolvedMaster = nil
        XCTAssertTrue(try execute(remote: remote, asset: Self.jetton(id: Self.peerJetton)).transactions.isEmpty)
        remote.failMasterLookup = true
        XCTAssertThrowsError(try execute(remote: remote, asset: Self.jetton(id: Self.ownerJetton)))
    }

    func testSwapHistoryRejectsOtherOwnersAndRetainsPendingAndFailureStatus() throws {
        let other = try Self.event(actions: [Self.swapAction(user: Self.peer)])
        let unrelated = TestTonHistoryRemote(response: .init(events: [other], next_from: 100))
        XCTAssertTrue(try execute(remote: unrelated, asset: Self.jetton(id: Self.master)).transactions.isEmpty)
        let pending = try Self.event(actions: [Self.swapAction(status: "failed")], pending: true)
        let remote = TestTonHistoryRemote(response: .init(events: [pending], next_from: 100))
        XCTAssertEqual(try execute(remote: remote, asset: Self.jetton(id: Self.master)).transactions.first?.status, .pending)
        remote.response = .init(events: [try Self.event(actions: [Self.swapAction(status: "failed")])], next_from: 0)
        XCTAssertEqual(try execute(remote: remote, asset: Self.jetton(id: Self.master)).transactions.first?.status, .rejected)
    }

    func testNativeTonSwapUsesNanotonsAndDoesNotNeedJettonAliasLookup() throws {
        let remote = TestTonHistoryRemote(response: .init(events: [try Self.event(actions: [Self.swapAction(nativeInput: true)])], next_from: 0))
        let transaction = try XCTUnwrap(execute(remote: remote).transactions.first)
        XCTAssertEqual(transaction.peerId, Self.native.id)
        XCTAssertEqual(Decimal(string: transaction.details), Decimal(2))
        XCTAssertEqual(transaction.amount.decimalValue, Decimal(string: "3.5"))
        XCTAssertEqual(remote.masterLookups, 0)
    }

    @MainActor
    func testRestoredSwapRendersSymbolsAndAmountsWithoutRequiringCurrentHoldings() throws {
        let remote = TestTonHistoryRemote(response: .init(events: [try Self.event(actions: [Self.swapAction()])], next_from: 0))
        let transaction = try XCTUnwrap(execute(remote: remote, asset: Self.jetton(id: Self.master)).transactions.first)
        let chainAsset = ChainAsset(chain: Self.chain(), asset: Self.jetton(id: Self.ownerJetton))
        let details = SwapTransactionViewModelFactory().createViewModel(wallet: AccountGenerator.generateMetaAccount(), chainAsset: chainAsset,
            transaction: transaction, priceData: nil, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(details.amountsText.string.contains("1.250 JET"), details.amountsText.string)
        XCTAssertTrue(details.amountsText.string.contains("3.500 OUT"), details.amountsText.string)
        XCTAssertEqual(details.txHash, transaction.transactionId)
        let factory = WalletTransactionHistoryViewModelFactory(balanceFormatterFactory: AssetBalanceFormatterFactory(), includesFeeInAmount: false,
            transactionTypes: [], chainAsset: chainAsset, iconGenerator: UniversalIconGenerator())
        var sections: [WalletTransactionHistorySection] = []
        _ = try factory.merge(newItems: [transaction], into: &sections, locale: Locale(identifier: "en_US"))
        let amount = try XCTUnwrap(sections.first?.items.first?.amountString)
        XCTAssertTrue(amount.contains("1.250 JET"), amount)
        XCTAssertTrue(amount.contains("3.500 OUT"), amount)
    }

    func testGeneratedTonAPIWalletDataResolvesZeroBalanceAliasAndRejectsWrongOwner() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestTonHistoryURLProtocol.self]
        func cell(_ address: String) throws -> String {
            try Builder().store(TonSwift.Address.parse(address)).endCell().toBoc().map { String(format: "%02x", $0) }.joined()
        }
        var encodedOwner = try cell(Self.owner)
        let encodedMaster = try cell(Self.master)
        var corrupt = false
        TestTonHistoryURLProtocol.handler = { request in
            XCTAssertTrue(request.url?.path.contains(Self.ownerJetton) == true)
            XCTAssertTrue(request.url?.path.hasSuffix("/methods/get_wallet_data") == true)
            let result: [String: Any] = ["success": true, "exit_code": 0, "stack": [
                ["type": "num", "num": "0x0"],
                ["type": "cell", "cell": corrupt ? "b5ee9c7201010201000200020000" : encodedOwner],
                ["type": "cell", "cell": encodedMaster],
                ["type": "cell", "cell": ""]
            ]]
            return try JSONSerialization.data(withJSONObject: result)
        }
        defer { TestTonHistoryURLProtocol.handler = nil }
        let remote = TonHistoryRemoteClient(clientProvider: { _ in
            TonAPIClientFactory(tonAPIURL: URL(string: "https://tonapi.io")!, token: "").tonAPIClient(configuration: configuration)
        })
        let master = try await remote.jettonMaster(walletAddress: Self.ownerJetton, owner: Self.owner, chain: Self.chain())
        XCTAssertEqual(master, Self.master)
        encodedOwner = try cell(Self.peer)
        let unrelated = try await remote.jettonMaster(walletAddress: Self.ownerJetton, owner: Self.owner, chain: Self.chain())
        XCTAssertNil(unrelated)
        corrupt = true
        do { _ = try await remote.jettonMaster(walletAddress: Self.ownerJetton, owner: Self.owner, chain: Self.chain()); XCTFail("Malformed BOC") } catch {}
    }

    func testInvalidTokenDecimalsThrowBeforeBalanceCatalogCanTrap() throws {
        var preview = try JSONDecoder().decode(Components.Schemas.JettonPreview.self, from: JSONSerialization.data(withJSONObject: [
            "address": Self.master, "name": "Token", "symbol": "JET", "decimals": 6,
            "image": "https://example.org/token.png", "verification": "whitelist"
        ]))
        for decimals in [-1, 256, Int.max] {
            preview.decimals = decimals
            XCTAssertThrowsError(try TonJettonInfo(jettonPreview: preview))
        }
        preview.decimals = 255
        XCTAssertEqual(try TonJettonInfo(jettonPreview: preview).fractionDigits, 255)
    }
}

extension TonHistoryOperationFactoryTests {
    func testTransferOnlyHistoryDoesNotWaitForFilteredOutSwapAliasLookup() throws {
        let remote = TestTonHistoryRemote(response: .init(events: [try Self.event(actions: [Self.jettonAction(), Self.swapAction()])], next_from: 0))
        remote.failMasterLookup = true
        let page = try execute(remote: remote, asset: Self.jetton(id: Self.ownerJetton), filters: [.init(type: .transfer, selected: true)])
        XCTAssertEqual(page.transactions.count, 1)
        XCTAssertEqual(page.transactions.first?.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(remote.masterLookups, 0)
    }
}
