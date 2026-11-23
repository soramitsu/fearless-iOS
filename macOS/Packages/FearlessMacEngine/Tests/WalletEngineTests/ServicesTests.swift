import Foundation
import SSFCrypto
import SSFModels
import WalletCore
import XCTest
@testable import WalletEngine

final class EngineStubURLProtocol: URLProtocol {
    struct Response { let status: Int; let body: Any }
    private static let lock = NSLock()
    private static var responder: ((URLRequest) throws -> Any)?
    static func install(_ respond: @escaping (URLRequest) throws -> Any) {
        lock.withLock { responder = respond }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let handler = Self.lock.withLock { Self.responder }
            let json = try XCTUnwrap(handler)(request)
            let custom = json as? Response
            let data = try JSONSerialization.data(withJSONObject: custom?.body ?? json)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: XCTUnwrap(request.url),
                statusCode: custom?.status ?? 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            ))
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }

    override func stopLoading() {}
    static func body(_ request: URLRequest) throws -> [String: Any] {
        var bytes = request.httpBody ?? Data()
        if bytes.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buf = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = stream.read(&buf, maxLength: buf.count)
                guard count > 0 else { break }
                bytes.append(contentsOf: buf.prefix(count))
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    }
}

final class ServicesTests: XCTestCase {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    func services() -> WalletServices {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [EngineStubURLProtocol.self]
        return WalletEngineFactory.makeLiveServices(configuration: .init(
            storageDirectory: directory,
            keychainService: directory.lastPathComponent,
            urlSession: URLSession(configuration: cfg)
        ))
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testSubscriptionIDsPreserveTheirJSONType() throws {
        let values = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(#"[7,"7",true,0.5,null]"#.utf8)) as? [Any])
        XCTAssertEqual(RPCSocket.Token(values[0]), .number(7))
        XCTAssertEqual(RPCSocket.Token(values[1]), .string("7"))
        XCTAssertEqual(RPCSocket.Token(values[0])?.value as? Int, 7)
        XCTAssertEqual(RPCSocket.Token(values[1])?.value as? String, "7")
        for invalid in values.dropFirst(2) {
            XCTAssertNil(RPCSocket.Token(invalid))
        }
    }

    func testCatalogAndNetworkPreferences() async throws {
        let svc = services(), bsc = ChainID("eip155:56")
        let chains = await svc.catalog.chains(), assets = await svc.catalog.assets()
        XCTAssertEqual(Set(chains.map(\.id)).count, 9)
        XCTAssertEqual(Set(assets.map(\.id)).count, 13)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        for chain in chains {
            let nodes = await svc.nodes.nodes(for: chain.id)
            XCTAssertFalse(nodes.isEmpty)
            let icon = try XCTUnwrap(chain.iconName)
            XCTAssertTrue(FileManager.default
                .fileExists(atPath: root
                    .appendingPathComponent("remote-config/production/icons/chains/white/" + icon + ".svg").path))
            XCTAssertTrue(assets.contains { $0.id == chain.nativeAssetID })
        }
        for asset in assets {
            XCTAssertTrue(chains.contains { $0.id == asset.chainID })
        }
        let custom = try XCTUnwrap(URL(string: "https://stub.example/rpc"))
        EngineStubURLProtocol.install { _ in ["jsonrpc": "2.0", "id": 1, "result": "0x1"] }
        do {
            _ = try await svc.nodes
                .addCustomNode(name: "wrong", url: custom, for: bsc); XCTFail("Wrong network accepted")
        } catch { XCTAssertTrue(error is WalletError) }
        EngineStubURLProtocol.install { _ in ["jsonrpc": "2.0", "id": 1, "result": "0x38"] }
        let node = try await svc.nodes.addCustomNode(name: "Custom", url: custom, for: bsc)
        await svc.nodes.selectNode(node, for: bsc)
        let reopened = services()
        let selection = await reopened.nodes.selectedNode(for: bsc)
        XCTAssertEqual(selection, node)
        await reopened.nodes.removeCustomNode(node, for: bsc)
        let cleared = await reopened.nodes.selectedNode(for: bsc)
        XCTAssertNil(cleared)
    }

    func testStubbedEVMSendAndLocalActivity() async throws {
        let svc = services(), pass = "Published-Test-Password2026"
        let bsc = ChainID("eip155:56"), id = AssetID.native(bsc)
        let block = "0x" + String(repeating: "01", count: 32)
        let releaseReceipt = DispatchSemaphore(value: 0)
        var acceptedHash: String?
        EngineStubURLProtocol.install { req in
            let body = try EngineStubURLProtocol.body(req)
            let value: Any
            switch body["method"] as? String {
            case "eth_chainId": value = "0x38"
            case "eth_getBalance": value = "0xde0b6b3a7640000"
            case "eth_getTransactionCount": value = "0x1"
            case "eth_estimateGas": value = "0x5208"
            case "eth_gasPrice": value = "0x3b9aca00"
            case "eth_getBlockByNumber": value = ["hash": block, "number": "0x20"]
            case "eth_sendRawTransaction":
                let signed = try XCTUnwrap((body["params"] as? [String])?.first)
                let hash = try Data(hexStringSSF: signed).keccak256().toHex(includePrefix: true)
                acceptedHash = hash
                value = hash
            case "eth_getTransactionReceipt":
                guard releaseReceipt.wait(timeout: .now() + 15) == .success else { throw URLError(.timedOut) }
                value = try [
                    "blockHash": block,
                    "transactionHash": XCTUnwrap(acceptedHash),
                    "blockNumber": "0x20",
                    "status": "0x1",
                    "gasUsed": "0x5208",
                    "effectiveGasPrice": "0x1dcd6500"
                ]
            default: throw URLError(.unsupportedURL)
            }
            return ["id": 1, "jsonrpc": "2.0", "result": value] as [String: Any]
        }
        try await svc.vault.initialize(password: pass)
        let wallet = try await svc.wallets.addWallet(
            name: "Published example",
            source: .seed(hex: String(repeating: "46", count: 32), ecosystem: .evm, options: .standard)
        )
        let node = try await svc.nodes.addCustomNode(name: "Test RPC", url: XCTUnwrap(URL(string: "https://bsc.invalid")), for: bsc)
        await svc.nodes.selectNode(node, for: bsc)
        let recipient = "0x" + String(repeating: "35", count: 20)
        let amount = try XCTUnwrap(TokenAmount(units: "100", decimals: 18))
        let req = TransferRequest(walletID: wallet.id, assetID: id, recipient: recipient, amount: amount)
        let results = await svc.balances.balances(of: wallet.id, assets: [id, .native("invalid")])
        XCTAssertEqual(try results[id]?.get().total.units, "1000000000000000000")
        XCTAssertThrowsError(try results[.native("invalid")]?.get())
        let prepared = await svc.transfers.prepare(req)
        XCTAssertTrue(prepared.canSubmit)
        XCTAssertEqual(prepared.fee?.amount.units, "21000000000000")
        do { _ = try await svc.transfers.submit(req, approval: .password("wrong")); XCTFail("Signed without approval") }
        catch { XCTAssertEqual(error as? WalletError, .wrongPassword) }
        XCTAssertNil(acceptedHash)
        let stream = try await svc.transfers.submit(req, approval: .password(pass))
        releaseReceipt.signal()
        var rows: [TransferProgress] = []
        for try await progress in stream {
            rows.append(progress)
        }
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows.first, .signed)
        XCTAssertEqual(rows.last, .finalized)
        let activity = try await svc.activity.activity(of: wallet.id, assets: [id])
        XCTAssertEqual(activity.items.count, 1)
        XCTAssertEqual(activity.items.first?.hash, acceptedHash)
        XCTAssertEqual(activity.items.first?.status, .success)
        XCTAssertEqual(activity.items.first?.fee?.units, "10500000000000")
        XCTAssertNotNil(activity.unavailable[bsc])
    }

    func testERC20FeeQuoteUsesTokenCalldataAndNativeGas() async throws {
        let services = services()
        let chain = ChainID("eip155:1")
        let assets = await services.catalog.assets()
        let token = try XCTUnwrap(assets.first { $0.chainID == chain && $0.symbol == "USDT" }?.id)
        let sender = "0x" + String(repeating: "11", count: 20)
        let recipient = "0x" + String(repeating: "22", count: 20)
        let contract = String(token.key.dropFirst(6))
        let tokenAmount = String(repeating: "0", count: 63) + "7"
        EngineStubURLProtocol.install { request in
            let body = try EngineStubURLProtocol.body(request)
            let params = try XCTUnwrap(body["params"] as? [Any])
            let result: Any
            switch body["method"] as? String {
            case "eth_chainId": result = "0x1"
            case "eth_call":
                let call = try XCTUnwrap(params.first as? [String: String])
                XCTAssertEqual(call["to"], contract)
                XCTAssertEqual(call["data"], "0x70a08231" + String(repeating: "0", count: 24) + sender.dropFirst(2))
                result = "0x" + tokenAmount
            case "eth_estimateGas":
                let call = try XCTUnwrap(params.first as? [String: String])
                XCTAssertEqual(call["value"], "0x0")
                XCTAssertEqual(call["to"], contract)
                XCTAssertEqual(
                    call["data"],
                    "0xa9059cbb" + String(repeating: "0", count: 24) + recipient.dropFirst(2) + tokenAmount
                )
                result = "0xc350"
            case "eth_getTransactionCount": result = "0x1"
            case "eth_getBlockByNumber": result = ["baseFeePerGas": "0xa"]
            case "eth_maxPriorityFeePerGas": result = "0x2"
            case "eth_getBalance": result = "0x200000"
            default: throw URLError(.unsupportedURL)
            }
            return ["id": 1, "jsonrpc": "2.0", "result": result] as [String: Any]
        }
        let nodes = await services.nodes.nodes(for: chain)
        let endpoint = try XCTUnwrap(nodes.first { $0.url.scheme == "https" })
        await services.nodes.selectNode(endpoint, for: chain)
        let wallet = try await services.wallets.addWallet(
            name: "Public sample",
            source: .watchOnly(substrateAddress: nil, evmAddress: sender)
        )
        let amount = try XCTUnwrap(TokenAmount(units: "7", decimals: 6))
        let preparation = await services.transfers.prepare(.init(
            walletID: wallet.id,
            assetID: token,
            recipient: recipient,
            amount: amount
        ))
        XCTAssertEqual(preparation.maxSendable, amount)
        XCTAssertEqual(preparation.issues, [.watchOnlyWallet])
        XCTAssertEqual(preparation.fee?.assetID, .native(chain))
        XCTAssertEqual(preparation.fee?.amount.units, "1375000")
    }

    func testChainlinkUSDFallbackUsesValidatedNetworkAndSignedRound() async throws {
        let svc = services()
        let word: (UInt64) -> String = { value in
            let hex = String(value, radix: 16)
            return String(repeating: "0", count: 64 - hex.count) + hex
        }
        let now = UInt64(Date().timeIntervalSince1970)
        EngineStubURLProtocol.install { req in
            if req.url?.host == "api.coingecko.com" {
                return [:] as [String: String]
            }
            let body = try EngineStubURLProtocol.body(req)
            if body["method"] as? String == "eth_chainId" {
                return ["id": 1, "result": "0xa4b1"] as [String: Any]
            }
            let data = "0x" + [1, 312_500_000, now - 5, now - 5, 1].map(word).joined()
            return ["id": 1, "result": data] as [String: Any]
        }
        let result = try await svc.prices.prices(for: ["polkadot"], in: .usd)
        XCTAssertEqual(result["polkadot"]?.value, 3.125)
        XCTAssertNil(result["polkadot"]?.change24h)
    }

    func testPricesUseCacheAndHistoryReadsVerifiedRelaySchema() async throws {
        let svc = services()
        let sender = "14ScPaB87Aj2upYK8wHjyEbqosuvur2NbSy7x7F1s3VmCfdL"
        let recipient = "165GUHN1DS7cSeJWA6VPQNnVcKGuyBB7F48PaEb2bcSLnYur"
        var priceRequests = 0
        EngineStubURLProtocol.install { request in
            if request.url?.host == "api.coingecko.com" {
                priceRequests += 1
                return ["polkadot": ["usd": 3.25, "usd_24h_change": -1.75]]
            }
            return ["data": ["historyElements": [["id": "event1", "success": true, "timestamp": 1_795_269_258, "extrinsicHash": "0xab",
                                                  "transfer": [
                                                      "amount": "1000",
                                                      "fee": "20",
                                                      "from": sender,
                                                      "to": recipient
                                                  ]]]]]
        }
        let first = try await svc.prices.prices(for: ["polkadot"], in: .usd)
        let second = try await svc.prices.prices(for: ["polkadot"], in: .usd)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first["polkadot"]?.value, 3.25)
        XCTAssertEqual(priceRequests, 1)
        let wallet = try await svc.wallets.addWallet(
            name: "Watch",
            source: .watchOnly(substrateAddress: recipient, evmAddress: nil)
        )
        let chain = try XCTUnwrap(Catalog.networks.first(where: { $0.name == "Polkadot" }))
        let page = try await svc.activity.activity(of: wallet.id, assets: [.native(chain.id)])
        XCTAssertEqual(page.items.first?.direction, .incoming)
        XCTAssertEqual(page.items.first?.timestamp.timeIntervalSince1970, 1_795_269_258)
        XCTAssertTrue(page.unavailable.isEmpty)
    }
}
