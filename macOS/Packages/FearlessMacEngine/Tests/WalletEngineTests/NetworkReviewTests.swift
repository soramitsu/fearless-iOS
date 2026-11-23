import Foundation
import SSFCrypto
import SSFUtils
import WalletCore
import XCTest
@testable import WalletEngine

extension TransferReviewTests {
    func testHistoryMapsFailedIncomingAndOutgoingAndPreservesLocalFailure() async throws {
        let id = try XCTUnwrap(Catalog.networks.first { $0.name == "Polkadot" }?.id)
        let wallet = try await store.addWallet(name: "Fixture", source: .watchOnly(
            substrateAddress: "165GUHN1DS7cSeJWA6VPQNnVcKGuyBB7F48PaEb2bcSLnYur", evmAddress: nil
        ))
        let item = try ActivityItem(
            id: "original",
            walletID: wallet.id,
            assetID: .native(id),
            direction: .outgoing,
            counterparty: "14ScPaB87Aj2upYK8wHjyEbqosuvur2NbSy7x7F1s3VmCfdL",
            amount: XCTUnwrap(TokenAmount(units: "100", decimals: 10)),
            fee: nil,
            timestamp: Date(),
            status: .failed,
            hash: "0x03",
            explorerURL: nil
        )
        try await store.record(item)
        EngineStubURLProtocol.install { request in
            let query = try XCTUnwrap(EngineStubURLProtocol.body(request)["query"] as? String)
            XCTAssertTrue(query.contains("extrinsicHash success transfer"))
            return try JSONSerialization.jsonObject(with: Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "failed-history", withExtension: "json"))))
        }
        let results = try await network.activity(of: wallet.id, assets: [.native(id)]).items
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results.first { $0.hash == "0x03" }, item)
        XCTAssertEqual(results.first { $0.hash == "0x01" }?.direction, .incoming)
        XCTAssertEqual(results.first { $0.hash == "0x02" }?.direction, .outgoing)
        XCTAssertTrue(results.allSatisfy { $0.status == .failed })
    }

    func testSelectedNodeFailureNeverContactsAnotherEndpoint() async throws {
        let selected = try await selectHTTPS(chain)
        var hosts: [URL?] = []
        EngineStubURLProtocol.install { request in
            hosts.append(request.url)
            throw URLError(.cannotConnectToHost)
        }
        do { _ = try await network.rpc(chain, "eth_blockNumber"); XCTFail("Selected node is down") }
        catch { XCTAssertTrue(try error.localizedDescription.contains(XCTUnwrap(selected.host))) }
        XCTAssertEqual(hosts, [selected])
    }

    func testCancellationRethrownAndSubscriptionSocketIndependentOfReads() async throws {
        let chain = ChainID("eip155:56")
        let endpoints = await network.nodes(for: chain)
        let first = try XCTUnwrap(endpoints.first)
        let started = expectation(description: "RPC started")
        let release = DispatchSemaphore(value: 0)
        EngineStubURLProtocol.install { _ in
            started.fulfill()
            _ = release.wait(timeout: .now() + 3)
            throw URLError(.cancelled)
        }
        XCTAssertEqual(first.url.scheme, "https")
        let task = Task { try await network.rpc(chain, "eth_blockNumber") }
        await fulfillment(of: [started], timeout: 4)
        task.cancel()
        release.signal()
        do { _ = try await task.value; XCTFail("Cancelled call succeeded") } catch { XCTAssertTrue(error is CancellationError) }
        var retried: URL?
        EngineStubURLProtocol.install { req in retried = req.url; return ["id": 1, "result": "0x38"] }
        _ = try await network.rpc(chain, "eth_blockNumber")
        XCTAssertEqual(retried, first.url)

        let url = try XCTUnwrap(URL(string: "wss://one.invalid"))
        let other = try XCTUnwrap(URL(string: "wss://two.invalid"))
        let watch = await network.socket(url, chain, forWatch: true)
        let read = await network.socket(url, chain)
        let newRead = await network.socket(other, chain)
        XCTAssertFalse(watch === read)
        XCTAssertFalse(watch === newRead)
        let secondWatch = await network.socket(url, chain, forWatch: true)
        XCTAssertFalse(watch === secondWatch)
    }

    func testPinnedRuntimeRejectsWrongCodeOnColdAndWarmRegistry() async throws {
        let snapshot = try XCTUnwrap(MetadataSnapshot.all.first)
        let chain = ChainID(snapshot.genesis)
        _ = try await selectHTTPS(chain)
        var code = "wrong", fallback = false
        install { method, _ in
            switch method {
            case "chain_getBlockHash": return "0x" + snapshot.genesis
            case "state_getRuntimeVersion": return ["specVersion": snapshot.specVersion, "transactionVersion": snapshot.transactionVersion]
            case "state_getStorageHash": return code
            default: fallback = true; throw URLError(.unsupportedURL)
            }
        }
        for expected in [false, true, false] {
            code = expected ? snapshot.codeHash : "wrong"
            do { _ = try await network.runtime(chain, block: block); XCTAssertTrue(expected) }
            catch { XCTAssertFalse(expected); XCTAssertEqual(error as? WalletError, .network("Runtime code differs from the bundled snapshot.")) }
        }
        XCTAssertFalse(fallback)
    }

    func testMortalReconciliationRequiresNonceOrExpiryAndReadsDispatchEvents() async throws {
        let snapshot = try XCTUnwrap(MetadataSnapshot.all.first { $0.file.contains("polkadot-asset-hub") })
        let chain = ChainID(snapshot.genesis)
        _ = try await selectHTTPS(chain)
        let wallet = try await store.addWallet(name: "Fixture", source: .watchOnly(substrateAddress: "165GUHN1DS7cSeJWA6VPQNnVcKGuyBB7F48PaEb2bcSLnYur", evmAddress: nil))
        let calls = ["0x00", "0x01", "0x02"]
        let hashes = try calls.map { try Data(hexStringSSF: $0).blake2b32().toHex(includePrefix: true) }
        let recorded = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "dispatch", withExtension: "json")))) as? [String: Any])
        let storage = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "storage", withExtension: "json")))) as? [String: Any])
        let account = try XCTUnwrap((storage["system"] as? [String: String])?["value"])
        let events = try XCTUnwrap(recorded["storageValue"] as? String)
        var accountNonce = "00", head = 101, blockReads = 0, eventReads = 0
        let headHash = block
        install { method, params in
            switch method {
            case "chain_getBlockHash":
                let number = try XCTUnwrap(params.first as? Int)
                return number == 0 ? "0x" + snapshot.genesis : String(format: "0x%064x", number)
            case "chain_getFinalizedHead": return headHash
            case "chain_getHeader": return ["number": "0x" + String(head, radix: 16)]
            case "state_getRuntimeVersion": return ["specVersion": snapshot.specVersion, "transactionVersion": snapshot.transactionVersion]
            case "state_getStorageHash": return snapshot.codeHash
            case "state_getStorage":
                if params.first as? String == recorded["storageKey"] as? String {
                    eventReads += 1
                    if eventReads == 1 {
                        throw RPCFault(message: "Read interrupted")
                    }
                    return events
                }
                return "0x" + accountNonce + String(account.dropFirst(4))
            case "chain_getBlock":
                blockReads += 1
                let included = params.first as? String == String(format: "0x%064x", 101)
                return ["block": ["header": ["parentHash": headHash], "extrinsics": included ? calls : []] as [String: Any]]
            default: throw URLError(.unsupportedURL)
            }
        }
        func add(_ hash: String, nonce: UInt32, birth: UInt64, next: UInt64? = nil) async throws {
            let item = try ActivityItem(id: hash, walletID: wallet.id, assetID: .native(chain), direction: .outgoing, counterparty: nil, amount: XCTUnwrap(TokenAmount(units: "100", decimals: 10)), fee: nil, timestamp: Date(), status: .pending, hash: hash, explorerURL: nil)
            try await store.record(item, mortality: .init(nonce: nonce, birth: birth, nextHeight: next))
        }
        try await add(hashes[0], nonce: 1, birth: 100)
        try await add(hashes[2], nonce: 1, birth: 100)
        await network.reconcileAfterUnlock()
        XCTAssertEqual(blockReads, 0)
        accountNonce = "02"
        await network.reconcileAfterUnlock()
        var items = try await store.localActivity(wallet.id)
        XCTAssertEqual(items.map(\.status), [.pending, .failed])
        let target = String(format: "0x%064x", 101)
        // Exercise the finalized subscription retry path with the same recorded events.
        eventReads = 0
        _ = try await network.pollFinality(until: Date().addingTimeInterval(5)) {
            try await self.network.confirmDispatch(chain, block: target, hash: hashes[0])
            return .confirmed(nil)
        }
        XCTAssertEqual(eventReads, 2)
        await network.reconcileAfterUnlock()
        head = 164
        try await add("0x03", nonce: 9, birth: 100, next: 163)
        await network.reconcileAfterUnlock()
        items = try await store.localActivity(wallet.id)
        XCTAssertEqual(items.map(\.status), [.success, .failed, .pending])
        XCTAssertTrue(items[2].title?.contains("outcome unknown") == true)
        let before = blockReads
        await network.reconcileAfterUnlock()
        XCTAssertEqual(before, blockReads)
    }

    func testSubstrateSubmitRefusesHigherPartialFee() async throws {
        let snapshot = try XCTUnwrap(MetadataSnapshot.all.first { $0.file.contains("polkadot-asset-hub") })
        let chain = ChainID(snapshot.genesis)
        _ = try await selectHTTPS(chain)
        try await store.initialize(password: password)
        let wallet = try await store.addWallet(name: "Fixture", source: .seed(hex: sampleSeed, ecosystem: .substrate, options: .standard))
        let storage = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "storage", withExtension: "json")))) as? [String: Any])
        let account = try XCTUnwrap((storage["system"] as? [String: String])?["value"])
        var fee = "100"
        let block = self.block
        install { method, _ in
            switch method {
            case "chain_getBlockHash": return "0x" + snapshot.genesis
            case "chain_getFinalizedHead": return block
            case "state_getRuntimeVersion": return ["specVersion": snapshot.specVersion, "transactionVersion": snapshot.transactionVersion]
            case "state_getStorageHash": return snapshot.codeHash
            case "state_getStorage": return account
            case "system_accountNextIndex": return 1
            case "chain_getHeader": return ["number": "0x10"]
            case "payment_queryInfo": return ["partialFee": fee]
            default: XCTFail("Unexpected RPC"); throw URLError(.unsupportedURL)
            }
        }
        let req = try TransferRequest(walletID: wallet.id, assetID: .native(chain), recipient: "165GUHN1DS7cSeJWA6VPQNnVcKGuyBB7F48PaEb2bcSLnYur", amount: XCTUnwrap(TokenAmount(units: "100", decimals: 10)))
        let reviewed = await network.prepare(req)
        XCTAssertTrue(reviewed.canSubmit)
        fee = "101"
        do { _ = try await network.submit(req, approval: .password(password)); XCTFail("Higher partial fee accepted") }
        catch { XCTAssertTrue(error.localizedDescription.contains("exceeds the reviewed fee")) }
    }
}

extension TransferReviewTests {
    func testMaximumQuoteFailureLeavesValidReviewAndPreflightNeverRecordsASend() async throws {
        var denyIdentity = false, sent = false
        install { method, params in
            switch method {
            case "eth_chainId": return denyIdentity ? "0x38" : "0x1"
            case "eth_getBalance": return "0x1000000"
            case "eth_estimateGas":
                guard (params.first as? [String: String])?["value"] == "0x64" else {
                    throw RPCFault(message: "Cannot estimate this amount")
                }
                return "0x5208"
            case "eth_getBlockByNumber": return ["baseFeePerGas": "0xa"]
            case "eth_getTransactionCount", "eth_maxPriorityFeePerGas": return "0x1"
            case "eth_sendRawTransaction": sent = true; throw URLError(.unsupportedURL)
            default: throw URLError(.unsupportedURL)
            }
        }
        let req = try await request()
        let reviewed = await network.prepare(req)
        XCTAssertTrue(reviewed.canSubmit)
        XCTAssertNil(reviewed.maxSendable)
        denyIdentity = true
        var stages: [TransferProgress] = []
        do {
            for try await stage in try await network.submit(req, approval: .password(password)) {
                stages.append(stage)
            }
            XCTFail("Expected identity check to fail")
        } catch { guard case .network = error as? WalletError else { return XCTFail("Expected node identity failure") } }
        XCTAssertEqual(stages, [.signed])
        XCTAssertFalse(sent)
        let records = try await store.localActivity(req.walletID)
        XCTAssertTrue(records.isEmpty)
    }

    func testLegacySubstrateRecordReconcilesByExactHashOnUnlock() async throws {
        let chain = try XCTUnwrap(Catalog.networks.first { $0.name == "Polkadot" })
        let sender = "165GUHN1DS7cSeJWA6VPQNnVcKGuyBB7F48PaEb2bcSLnYur"
        let recipient = "14ScPaB87Aj2upYK8wHjyEbqosuvur2NbSy7x7F1s3VmCfdL"
        let wallet = try await store.addWallet(name: "Legacy", source: .watchOnly(substrateAddress: sender, evmAddress: nil))
        let item = try ActivityItem(
            id: "old",
            walletID: wallet.id,
            assetID: .native(chain.id),
            direction: .outgoing,
            counterparty: recipient,
            amount: XCTUnwrap(TokenAmount(units: "100", decimals: 10)),
            fee: nil,
            timestamp: Date(),
            status: .pending,
            hash: "0x02",
            explorerURL: nil
        )
        try EngineFiles(directory: directory).write([item], "activity.json")
        EngineStubURLProtocol.install { request in
            let body = try EngineStubURLProtocol.body(request)
            XCTAssertEqual((body["variables"] as? [String: String])?["hash"], "0x02")
            return try JSONSerialization.jsonObject(with: Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "failed-history", withExtension: "json"))))
        }
        await network.reconcileAfterUnlock()
        let records = try await store.localActivity(wallet.id)
        XCTAssertEqual(records.first?.status, .failed)
    }

    func testFinalityDeadlineCancelsAnOutstandingRead() async throws {
        let clock = ContinuousClock(), start = clock.now
        do {
            _ = try await network.pollFinality(until: Date().addingTimeInterval(0.02)) {
                try await Task.sleep(for: .seconds(15))
                return .confirmed(nil)
            }
            XCTFail("Deadline passed")
        } catch { guard case .network = error as? WalletError else { return XCTFail("Expected unknown outcome") } }
        XCTAssertLessThan(start.duration(to: clock.now), .seconds(5))
    }
}
