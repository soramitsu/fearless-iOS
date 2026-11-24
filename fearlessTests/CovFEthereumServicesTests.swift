import BigInt
import SSFModels
import Web3
import Web3ContractABI
import XCTest
@testable import fearless

final class CovFEthereumServicesTests: XCTestCase {
    func testBaseQueriesReturnQuantitiesAndUsePendingNonce() async throws {
        let fixture = try CovFEthereumFixture()
        let service = BaseEthereumService(ws: fixture.web3.eth)
        let price = try await service.queryGasPrice()
        let priority = try await service.queryMaxPriorityFeePerGas()
        let gas = try await service.queryGasLimit(call: EthereumCall(to: fixture.key.address))
        let nonce = try await service.queryNonce(ethereumAddress: fixture.key.address)
        let supports = await service.checkChainSupportEip1559()
        XCTAssertEqual(price.quantity, 3)
        XCTAssertEqual(priority.quantity, 2)
        XCTAssertEqual(gas.quantity, 21000)
        XCTAssertEqual(nonce.quantity, 2)
        XCTAssertTrue(supports)
        let request = try XCTUnwrap(fixture.provider.requests.first { $0["method"] as? String == "eth_getTransactionCount" })
        XCTAssertEqual((request["params"] as? [String])?.last, "pending")
    }

    func testBaseQueryErrorsPropagateAndDisableEip1559() async throws {
        let fixture = try CovFEthereumFixture()
        let service = BaseEthereumService(ws: fixture.web3.eth)
        fixture.provider.failedMethods = ["eth_gasPrice", "eth_maxPriorityFeePerGas", "eth_estimateGas", "eth_getTransactionCount"]
        do { _ = try await service.queryGasPrice(); XCTFail("Expected RPC error") } catch { XCTAssertEqual((error as NSError).domain, "CovFRPC") }
        do { _ = try await service.queryMaxPriorityFeePerGas(); XCTFail("Expected RPC error") } catch { XCTAssertEqual((error as NSError).domain, "CovFRPC") }
        do {
            _ = try await service.queryGasLimit(call: EthereumCall(to: fixture.key.address))
            XCTFail("Expected RPC error")
        } catch { XCTAssertEqual((error as NSError).domain, "CovFRPC") }
        do {
            _ = try await service.queryNonce(ethereumAddress: fixture.key.address)
            XCTFail("Expected RPC error")
        } catch { XCTAssertEqual((error as NSError).domain, "CovFRPC") }
        let supports = await service.checkChainSupportEip1559()
        XCTAssertFalse(supports)
    }

    func testTokenAndNativeFeesUseGasTimesPriceOrBasePlusPriority() async throws {
        let fixture = try CovFEthereumFixture()
        for type in [EthereumAssetType.normal, .erc20, .bep20] {
            let transfer = fixture.transfer(type: type)
            let legacy = try await fixture.service.estimateFee(for: transfer)
            let modern = try await fixture.service.estimateFee(for: transfer, baseFeePerGas: EthereumQuantity(quantity: 10))
            XCTAssertEqual(legacy, 63000)
            XCTAssertEqual(modern, 252000)
        }
        XCTAssertEqual(fixture.provider.methods.filter { $0 == "eth_estimateGas" }.count, 6)
    }

    func testUnknownAssetAndInvalidReceiverRejectFeeAndSubmission() async throws {
        let fixture = try CovFEthereumFixture()
        let unknown = fixture.transfer(type: nil)
        do { _ = try await fixture.service.estimateFee(for: unknown); XCTFail("Expected unsupported asset") } catch { XCTAssertTrue(error is TransferServiceError) }
        do { _ = try await fixture.service.submit(transfer: unknown); XCTFail("Expected unsupported asset") } catch { XCTAssertTrue(error is TransferServiceError) }
        do {
            _ = try await fixture.service.estimateFee(for: unknown, baseFeePerGas: EthereumQuantity(quantity: 1))
            XCTFail("Expected unsupported asset")
        } catch { XCTAssertTrue(error is TransferServiceError) }
        let invalid = fixture.transfer(type: .normal, receiver: "bad")
        do { _ = try await fixture.service.estimateFee(for: invalid); XCTFail("Expected invalid address") } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
        XCTAssertTrue(fixture.provider.requests.isEmpty)
    }

    func testNativeAndTokenSubmissionsReturnHashAndUseBothTransactionTypes() async throws {
        let fixture = try CovFEthereumFixture()
        for modern in [true, false] {
            fixture.provider.failedMethods = modern ? [] : ["eth_maxPriorityFeePerGas"]
            for type in [EthereumAssetType.normal, .erc20, .bep20] {
                let hash = try await fixture.service.submit(transfer: fixture.transfer(type: type))
                XCTAssertEqual(hash, CovFEthereumProvider.hash)
                let request = try XCTUnwrap(fixture.provider.requests.last)
                XCTAssertEqual(request["method"] as? String, "eth_sendRawTransaction")
                let raw = try XCTUnwrap((request["params"] as? [String])?.first)
                XCTAssertEqual(raw.hasPrefix("0x02"), modern)
                XCTAssertGreaterThan(raw.count, 100)
            }
        }
    }

    func testSubmissionAndContractGasErrorsPropagate() async throws {
        let fixture = try CovFEthereumFixture()
        fixture.provider.failedMethods = ["eth_sendRawTransaction"]
        for type in [EthereumAssetType.normal, .erc20] {
            do { _ = try await fixture.service.submit(transfer: fixture.transfer(type: type)); XCTFail("Expected rejected transaction") }
            catch { XCTAssertEqual((error as NSError).domain, "CovFRPC") }
        }
        fixture.provider.failedMethods = ["eth_estimateGas"]
        do { _ = try await fixture.service.estimateFee(for: fixture.transfer(type: .erc20)); XCTFail("Expected failed gas estimate") }
        catch { XCTAssertEqual((error as NSError).domain, "CovFRPC") }
    }

    func testFeeSubscriptionReportsHeaderFeeAndReplacesSubscription() async throws {
        let fixture = try CovFEthereumFixture()
        let listener = CovFEthereumFeeListener()
        let received = expectation(description: "header fee")
        listener.onFee = { received.fulfill() }
        fixture.service.subscribeForFee(transfer: fixture.transfer(type: .normal), listener: listener)
        try fixture.provider.emitHeader(baseFee: "0xa")
        await fulfillment(of: [received], timeout: 10)
        XCTAssertEqual(listener.fees, [252000])
        fixture.service.subscribeForFee(transfer: fixture.transfer(type: .normal), listener: listener)
        XCTAssertEqual(fixture.provider.subscriptions, 2)
        XCTAssertEqual(fixture.provider.unsubscribed, ["cov-f-subscription"])
        fixture.service.unsubscribe()
        XCTAssertEqual(fixture.provider.unsubscribed.count, 2)
    }

    func testFeeSubscriptionReportsMissingBaseFeeAndProviderError() throws {
        let fixture = try CovFEthereumFixture()
        let listener = CovFEthereumFeeListener()
        fixture.service.subscribeForFee(transfer: fixture.transfer(type: .normal), listener: listener)
        try fixture.provider.emitHeader(baseFee: nil)
        XCTAssertEqual(listener.errors.count, 1)
        XCTAssertTrue(listener.errors.first is TransferServiceError)
        fixture.provider.eventFailure?(NSError(domain: "header", code: 1))
        XCTAssertEqual(listener.errors.count, 2)
        XCTAssertEqual((listener.errors.last as NSError?)?.domain, "header")
    }
}

final class CovFEthereumNftTransferTests: XCTestCase {
    func testErc721And1155FeesAndSubmissions() async throws {
        let fixture = try CovFEthereumFixture()
        let service = EthereumNftTransferService(ws: fixture.web3.eth, privateKey: fixture.key, senderAddress: fixture.sender, logger: nil)
        for type: NFTTokenType? in [.erc721, .erc1155, nil] {
            let transfer = fixture.nft(type: type)
            let legacy = try await service.estimateFee(for: transfer)
            let modern = try await service.estimateFee(for: transfer, baseFeePerGas: EthereumQuantity(quantity: 10))
            let hash = try await service.submit(transfer: transfer)
            XCTAssertEqual(legacy, 63000)
            XCTAssertEqual(modern, 252000)
            XCTAssertEqual(hash, CovFEthereumProvider.hash)
        }
    }

    func testMissingNftFieldsAndRpcFailureAreReported() async throws {
        let fixture = try CovFEthereumFixture()
        let service = EthereumNftTransferService(ws: fixture.web3.eth, privateKey: fixture.key, senderAddress: fixture.sender, logger: nil)
        for transfer in [fixture.nft(contract: nil), fixture.nft(token: nil)] {
            do { _ = try await service.estimateFee(for: transfer); XCTFail("Expected missing NFT field") }
            catch { XCTAssertTrue(error is EthereumNftTransferServiceError) }
            do { _ = try await service.submit(transfer: transfer); XCTFail("Expected missing NFT field") }
            catch { XCTAssertTrue(error is EthereumNftTransferServiceError) }
        }
        fixture.provider.failedMethods = ["eth_estimateGas"]
        do { _ = try await service.estimateFee(for: fixture.nft()); XCTFail("Expected failed gas estimate") }
        catch { XCTAssertEqual((error as NSError).domain, "CovFRPC") }
        fixture.provider.failedMethods = ["eth_sendRawTransaction"]
        do { _ = try await service.submit(transfer: fixture.nft()); XCTFail("Expected rejected transaction") }
        catch { XCTAssertEqual((error as NSError).domain, "CovFRPC") }
    }

    func testNftHeaderUsesLegacyFeeWhenBaseFeeMissingAndUnsubscribesOnRelease() async throws {
        let fixture = try CovFEthereumFixture()
        var service: EthereumNftTransferService? = EthereumNftTransferService(
            ws: fixture.web3.eth, privateKey: fixture.key, senderAddress: fixture.sender, logger: nil
        )
        let listener = CovFEthereumFeeListener()
        let received = expectation(description: "NFT fee")
        received.expectedFulfillmentCount = 2
        listener.onFee = { received.fulfill() }
        service?.subscribeForFee(transfer: fixture.nft(), listener: listener)
        try fixture.provider.emitHeader(baseFee: nil)
        try fixture.provider.emitHeader(baseFee: "0xa")
        await fulfillment(of: [received], timeout: 10)
        XCTAssertEqual(listener.fees.sorted(), [63000, 252000])
        fixture.provider.eventFailure?(NSError(domain: "nft-header", code: 2))
        XCTAssertEqual(listener.errors.count, 1)
        service = nil
        XCTAssertEqual(fixture.provider.unsubscribed, ["cov-f-subscription"])
    }
}

private final class CovFEthereumFixture {
    let provider = CovFEthereumProvider()
    let key: EthereumPrivateKey
    lazy var web3 = Web3(provider: provider)
    var sender: String { key.address.hex(eip55: false) }
    lazy var service = EthereumTransferService(ws: web3.eth, privateKey: key, senderAddress: sender)
    static let contract = "0x2222222222222222222222222222222222222222"

    init() throws { key = try EthereumPrivateKey(privateKey: Array(repeating: 1, count: 32)) }

    func asset(type: EthereumAssetType?) -> ChainAsset {
        let asset = AssetModel(id: Self.contract, name: "Token", symbol: "TKN", precision: 18, isUtility: true, isNative: true, ethereumType: type)
        let chain = ChainModel(
            rank: nil, disabled: false, chainId: "1", parentId: nil, paraId: nil, name: "Ethereum", assets: [asset],
            xcm: nil, nodes: [], addressPrefix: 0, icon: nil, options: [.ethereum], iosMinAppVersion: nil, identityChain: nil
        )
        return ChainAsset(chain: chain, asset: asset)
    }

    func transfer(type: EthereumAssetType?, receiver: String? = nil) -> Transfer {
        Transfer(chainAsset: asset(type: type), amount: 100, receiver: receiver ?? sender, tip: nil, appId: nil)
    }

    func nft(type: NFTTokenType? = .erc721, contract: String? = CovFEthereumFixture.contract, token: String? = "0x01") -> NftTransfer {
        let nft = NFT(
            chain: asset(type: .normal).chain, tokenId: token, title: "Test", description: nil, smartContract: contract,
            metadata: nil, mediaThumbnail: nil, media: nil, tokenType: type, collectionName: nil, collection: nil
        )
        return NftTransfer(nft: nft, receiver: sender, value: 2)
    }
}

private final class CovFEthereumFeeListener: TransferFeeEstimationListener {
    var fees: [BigUInt] = []
    var errors: [Error] = []
    private let lock = NSLock()
    var onFee: (() -> Void)?
    func didReceiveFee(fee: BigUInt) { lock.lock(); fees.append(fee); lock.unlock(); onFee?() }
    func didReceiveFeeError(feeError: Error) { lock.lock(); errors.append(feeError); lock.unlock() }
}

private final class CovFEthereumProvider: Web3BidirectionalProvider {
    static let hash = "0x" + String(repeating: "ab", count: 32)
    var failedMethods: Set<String> = []
    private let lock = NSLock()
    private var recorded: [[String: Any]] = []
    var requests: [[String: Any]] { lock.lock(); defer { lock.unlock() }; return recorded }
    var methods: [String] { requests.compactMap { $0["method"] as? String } }
    var subscriptions = 0
    var unsubscribed: [String] = []
    var event: ((Data) throws -> Void)?
    var eventFailure: ((Error) -> Void)?

    func send<Params: Codable, Result: Codable>(request: RPCRequest<Params>, response: @escaping (Web3Response<Result>) -> Void) {
        do {
            let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request))
            let recordedRequest = try XCTUnwrap(object as? [String: Any])
            lock.lock()
            recorded.append(recordedRequest)
            lock.unlock()
            if failedMethods.contains(request.method) { throw NSError(domain: "CovFRPC", code: 1) }
            let values = ["eth_gasPrice": "0x3", "eth_maxPriorityFeePerGas": "0x2", "eth_estimateGas": "0x5208",
                          "eth_getTransactionCount": "0x2", "eth_sendRawTransaction": Self.hash]
            let value = try XCTUnwrap(values[request.method])
            response(Web3Response(status: .success(try JSONDecoder().decode(Result.self, from: JSONEncoder().encode(value)))))
        } catch { response(Web3Response(error: error)) }
    }

    func subscribe<Params: Codable, Result: Codable>(
        request _: RPCRequest<Params>, response: @escaping (Web3Response<String>) -> Void, onEvent: @escaping (Web3Response<Result>) -> Void
    ) {
        subscriptions += 1
        response(Web3Response(status: .success("cov-f-subscription")))
        event = { data in onEvent(Web3Response(status: .success(try JSONDecoder().decode(Result.self, from: data)))) }
        eventFailure = { onEvent(Web3Response(error: $0)) }
    }

    func unsubscribe(subscriptionId: String, completion: @escaping (Bool) -> Void) {
        unsubscribed.append(subscriptionId)
        completion(true)
    }

    func emitHeader(baseFee: String?) throws {
        var header: [String: Any] = [
            "parentHash": "0x00", "sha3Uncles": "0x00", "transactionsRoot": "0x00", "stateRoot": "0x00", "receiptsRoot": "0x00",
            "miner": CovFEthereumFixture.contract, "difficulty": "0x0", "extraData": "0x", "gasLimit": "0x5208", "gasUsed": "0x0", "timestamp": "0x1"
        ]
        header["baseFeePerGas"] = baseFee
        try event?(JSONSerialization.data(withJSONObject: header))
    }
}
