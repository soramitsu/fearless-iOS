import BigInt
import Foundation
import SSFCrypto
import WalletCore
import XCTest
@testable import WalletEngine

private extension NetworkServices {
    func expireReview(_ request: TransferRequest) {
        if let review = reviewedFees[request] {
            reviewedFees[request] = FeeReview(quote: review.quote, expires: .now.advanced(by: .seconds(-1)))
        }
    }
}

final class TransferReviewTests: XCTestCase {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let password = "Published-Test-Password2026"
    let destination = "0x" + String(repeating: "35", count: 20)
    let sampleSeed = String(repeating: "46", count: 32)
    let chain = ChainID("eip155:1")
    let block = "0x" + String(repeating: "01", count: 32)
    var store: EngineStore!
    var network: NetworkServices!

    override func setUp() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [EngineStubURLProtocol.self]
        let session = URLSession(configuration: cfg)
        store = EngineStore(configuration: .init(storageDirectory: directory, keychainService: UUID().uuidString, urlSession: session))
        network = NetworkServices(store: store, session: session, tracking: .init(
            evmDeadline: 0.3,
            substrateDeadline: 0.3,
            firstDelay: 0.005,
            maximumDelay: 0.01
        ))
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func selectHTTPS(_ id: ChainID) async throws -> URL {
        let nodes = await network.nodes(for: id)
        let https = try XCTUnwrap(nodes.first { $0.url.scheme == "https" })
        await network.selectNode(https, for: id)
        return https.url
    }

    func install(_ handler: @escaping (String, [Any]) throws -> Any) {
        EngineStubURLProtocol.install { req in
            let body = try EngineStubURLProtocol.body(req)
            do {
                let value = try handler(XCTUnwrap(body["method"] as? String), XCTUnwrap(body["params"] as? [Any]))
                return ["id": 1, "result": value] as [String: Any]
            } catch let fault as RPCFault {
                return EngineStubURLProtocol.Response(status: 400, body: ["id": 1, "error": ["code": -32000, "message": fault.message]] as [String: Any])
            }
        }
    }

    func request() async throws -> TransferRequest {
        _ = try await selectHTTPS(chain)
        try await store.initialize(password: password)
        let wallet = try await store.addWallet(name: "Published vector", source: .seed(hex: sampleSeed, ecosystem: .evm, options: .standard))
        return try TransferRequest(
            walletID: wallet.id,
            assetID: .native(chain),
            recipient: destination,
            amount: XCTUnwrap(TokenAmount(units: "100", decimals: 18))
        )
    }

    func testMissingMismatchedAndPurgedReviewsCannotSubmit() async throws {
        install { method, _ in
            switch method {
            case "eth_chainId": return "0x1"
            case "eth_getBalance": return "0x1000000"
            case "eth_estimateGas": return "0x5208"
            case "eth_getBlockByNumber": return ["baseFeePerGas": "0xa"]
            case "eth_getTransactionCount", "eth_maxPriorityFeePerGas": return "0x1"
            default: XCTFail("Unexpected RPC method"); throw URLError(.badURL)
            }
        }
        let req = try await request()
        func assertMissing(_ req: TransferRequest) async {
            do { _ = try await network.submit(req, approval: .password(password)); XCTFail("Accepted without review") }
            catch { XCTAssertEqual(error as? WalletError, .transferRejected("Review this transfer for a current fee quote.")) }
        }
        await assertMissing(req)
        var other = req
        other.amount = try XCTUnwrap(TokenAmount(units: "101", decimals: 18))
        _ = await network.prepare(req)
        await assertMissing(other)
        await network.expireReview(req)
        await assertMissing(req)
        _ = await network.prepare(other)
        await assertMissing(req)
    }

    func testReviewedEnvelopeFreshNonceCandidateMaximumAndRetryAfterReceiptError() async throws {
        var submitting = false, base = "0xa", gasCalls: [String] = [], nonce = "0x1", expectedBytes = ""
        var hash = "", receiptReads = 0, finalizedReads = 0
        let block = self.block
        install { method, params in
            switch method {
            case "eth_chainId": return "0x1"
            case "eth_getBalance": return "0x1000000"
            case "eth_getTransactionCount": return nonce
            case "eth_maxPriorityFeePerGas":
                XCTAssertFalse(submitting); return "0x2"
            case "eth_estimateGas":
                XCTAssertFalse(submitting)
                try gasCalls.append(XCTUnwrap((params.first as? [String: String])?["value"]))
                return gasCalls.count == 1 ? "0x5208" : "0x7530" // 21,000 for request, 30,000 for maximum
            case "eth_getBlockByNumber":
                if params.first as? String == "latest" {
                    return ["baseFeePerGas": base]
                }
                finalizedReads += 1
                if finalizedReads == 1 {
                    throw RPCFault(message: "Read interrupted")
                }
                return ["number": "0x10", "hash": block]
            case "eth_sendRawTransaction":
                let raw = try XCTUnwrap(params.first as? String)
                XCTAssertEqual(raw, expectedBytes)
                hash = try Data(hexStringSSF: raw).keccak256().toHex(includePrefix: true)
                throw RPCFault(message: "already known")
            case "eth_getTransactionReceipt":
                receiptReads += 1
                if receiptReads == 1 {
                    throw RPCFault(message: "Read interrupted")
                }
                return ["transactionHash": hash, "blockHash": block, "blockNumber": "0x10", "status": "0x1"]
            default: throw URLError(.unsupportedURL)
            }
        }
        let req = try await request()
        let reviewed = await network.prepare(req)
        XCTAssertTrue(reviewed.canSubmit)
        XCTAssertEqual(reviewed.maxSendable?.units, String(0x1000000 - 30000 * 22 * 105 / 100))
        XCTAssertEqual(gasCalls, ["0x64", "0x" + String(0x1000000 - 21000 * 22, radix: 16)])
        submitting = true
        base = "0x15" // 21 + 2 > reviewed 22
        do { _ = try await network.submit(req, approval: .password(password)); XCTFail("Fee cap exceeded") }
        catch { XCTAssertTrue(error.localizedDescription.contains("exceeds")) }
        base = "0x13" // 19 + 2 fits even though a fresh 2 * base + tip quote would almost double.
        nonce = "0x8"
        let tx = try EVMTransfer(
            chain: 1,
            nonce: 8,
            gas: 21000,
            feeCap: 22,
            priority: 2,
            to: Data(hexStringSSF: destination),
            value: 100,
            input: Data()
        )
        let secret = try XCTUnwrap(WalletKeys.importSource(.seed(hex: sampleSeed, ecosystem: .evm, options: .standard)).secret)
        expectedBytes = try tx.encode(signature: secret.sign(tx.encode(), ecosystem: .evm)).toHex(includePrefix: true)
        var stages: [TransferProgress] = []
        for try await stage in try await network.submit(req, approval: .password(password)) {
            stages.append(stage)
        }
        XCTAssertEqual(stages.count, 4)
        XCTAssertEqual(stages.last, .finalized)
        XCTAssertEqual(stages.filter { $0 == .included(blockHash: block) }.count, 1)
        XCTAssertGreaterThanOrEqual(receiptReads, 3)
    }

    func testGasHeadroomAndPriceBounds() throws {
        XCTAssertEqual(try EVMTransfer.gasLimit(estimate: 21000, hasData: false), 21000)
        XCTAssertEqual(try EVMTransfer.gasLimit(estimate: 50001, hasData: true), 62502)
        XCTAssertThrowsError(try EVMTransfer.gasLimit(estimate: 20999, hasData: false))
        XCTAssertThrowsError(try EVMTransfer.gasLimit(estimate: 1_600_001, hasData: true))
        XCTAssertThrowsError(try EVMTransfer.gasLimit(estimate: 2_000_001, hasData: false))
        XCTAssertThrowsError(try EVMTransfer.validatePrice(0))
        XCTAssertNoThrow(try EVMTransfer.validatePrice(EVMTransfer.maximumPrice))
        XCTAssertThrowsError(try EVMTransfer.validatePrice(EVMTransfer.maximumPrice + 1))
    }

    func testDefinitiveRejectionAndUnknownOutcomeReconciledOnUnlockAndActivity() async throws {
        var failure: String? = "insufficient funds", hash = "", nonce = 0, status: String?, canonical = false
        let block = self.block
        install { method, params in
            switch method {
            case "eth_chainId": return "0x1"
            case "eth_getBalance": return "0x1000000"
            case "eth_getTransactionCount": return "0x" + String(nonce, radix: 16)
            case "eth_estimateGas": return "0x5208"
            case "eth_maxPriorityFeePerGas": return "0x1"
            case "eth_getBlockByNumber":
                if params.first as? String == "latest" {
                    return ["baseFeePerGas": "0xa"]
                }
                return ["hash": canonical ? block : "0x02", "number": "0x10"]
            case "eth_sendRawTransaction":
                if let failure {
                    throw RPCFault(message: failure)
                }
                hash = try Data(hexStringSSF: XCTUnwrap(params.first as? String)).keccak256().toHex(includePrefix: true)
                throw RPCFault(message: "known transaction: " + hash)
            case "eth_getTransactionReceipt":
                return ["transactionHash": hash, "blockNumber": "0x10", "blockHash": block, "status": status ?? "unexpected"]
            default: throw URLError(.unsupportedURL)
            }
        }
        let req = try await request()
        func send() async throws -> [TransferProgress] {
            _ = await network.prepare(req)
            var stages: [TransferProgress] = []
            for try await stage in try await network.submit(req, approval: .password(password)) {
                stages.append(stage)
            }
            return stages
        }
        let rejected = try await send()
        guard case .failed? = rejected.last else { return XCTFail("Expected explicit rejection") }
        failure = nil
        nonce += 1
        let waiting = try await send()
        guard case .outcomeUnknown? = waiting.last else { return XCTFail("Unconfirmed inclusion must remain unknown") }
        XCTAssertTrue(waiting.contains(.included(blockHash: block)))
        canonical = true
        var page = try await network.activity(of: req.walletID, assets: [req.assetID])
        XCTAssertEqual(page.items.first?.status, .pending) // malformed receipt status
        status = "0x0"
        page = try await network.activity(of: req.walletID, assets: [req.assetID])
        XCTAssertEqual(page.items.map(\.status), [.failed, .failed])
        nonce += 1
        canonical = false
        let reorg = try await send()
        guard case .outcomeUnknown? = reorg.last else { return XCTFail("Noncanonical receipt") }
        await store.lock()
        canonical = true
        status = "0x1"
        try await store.unlock(.password(password))
        // Read disk directly, so requesting Activity cannot trigger this reconciliation.
        for _ in 0 ..< 100 {
            if try await store.localActivity(req.walletID).last?.status == .success {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        let local = try await store.localActivity(req.walletID)
        XCTAssertEqual(local.map(\.status), [.failed, .failed, .success])
    }

    func testFinalizedEvenIfLocalUpdateFailsAndSlotReleasedAtAcceptance() async throws {
        let block = self.block
        var hash = ""
        let req = try await request()
        let accepted = expectation(description: "Accepted transfer released its slot")
        let release = DispatchSemaphore(value: 0)
        let directory = self.directory
        install { method, params in
            switch method {
            case "eth_chainId": return "0x1"
            case "eth_getBalance": return "0x1000000"
            case "eth_getTransactionCount", "eth_maxPriorityFeePerGas": return "0x1"
            case "eth_estimateGas": return "0x5208"
            case "eth_getBlockByNumber": return ["baseFeePerGas": "0xa", "number": "0x10", "hash": block]
            case "eth_sendRawTransaction":
                hash = try Data(hexStringSSF: XCTUnwrap(params.first as? String)).keccak256().toHex(includePrefix: true)
                return hash
            case "eth_getTransactionReceipt":
                accepted.fulfill()
                guard release.wait(timeout: .now() + 5) == .success else { throw URLError(.timedOut) }
                try Data("damaged local fixture".utf8).write(to: directory.appendingPathComponent("activity.json"))
                return ["blockHash": block, "blockNumber": "0x10", "transactionHash": hash, "status": "0x1"]
            default: throw URLError(.unsupportedURL)
            }
        }
        _ = await network.prepare(req)
        let stream = try await network.submit(req, approval: .password(password))
        await fulfillment(of: [accepted], timeout: 6)
        let slot = req.walletID.description + "/" + chain.rawValue
        let owner = try await store.beginTransfer(slot)
        release.signal()
        var stages: [TransferProgress] = []
        for try await stage in stream {
            stages.append(stage)
        }
        XCTAssertEqual(stages.last, .finalized)
        do { _ = try await store.beginTransfer(slot); XCTFail("Old tracker released newer owner's slot") }
        catch { XCTAssertTrue(error.localizedDescription.contains("awaiting node acceptance")) }
        await store.endTransfer(slot, owner: owner)
    }
}
