import BigInt
@testable import fearless
import Foundation
import SSFModels
import Web3
import XCTest

final class CovGChainlinkTests: XCTestCase {
    private let contract = "0x1111111111111111111111111111111111111111"

    func testPriceCallRequestsLatestRoundAndScalesAnswer() throws {
        let provider = CovGWeb3Provider()
        let words = [BigUInt(1), 12345, 2, 3, 1].map { value -> Data in
            let bytes = value.serialize()
            return Data(repeating: 0, count: 32 - bytes.count) + bytes
        }.reduce(Data(), +)
        provider.payload = try JSONEncoder().encode("0x" + words.map { String(format: "%02x", $0) }.joined())
        let operation = try XCTUnwrap(ChainlinkOperationFactoryImpl().priceCall(for: chainAsset(precision: 2), connection: Web3(provider: provider).eth))
        let price = try CovGOperationFixtures.run(operation)
        XCTAssertEqual(price.price, "123.45")
        XCTAssertEqual(price.priceId, contract)
        XCTAssertEqual(price.currencyId, "usd")
        XCTAssertEqual(price.coingeckoPriceId, "token")
        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request["method"] as? String, "eth_call")
        let params = try XCTUnwrap(request["params"] as? [Any])
        XCTAssertEqual(params.last as? String, "latest")
        XCTAssertEqual((params.first as? [String: Any])?["to"] as? String, contract)
    }

    func testMissingContractConnectionAndInvalidContractRejectBeforeRPC() throws {
        let factory = ChainlinkOperationFactoryImpl()
        let chain = try CovGOperationFixtures.chain()
        XCTAssertNil(factory.priceCall(for: ChainAsset(chain: chain, asset: CovGOperationFixtures.asset), connection: nil))
        XCTAssertNil(try factory.priceCall(for: chainAsset(precision: 2), connection: nil))
        let provider = CovGWeb3Provider()
        XCTAssertNil(try factory.priceCall(for: chainAsset(precision: 2, contract: "invalid"), connection: Web3(provider: provider).eth))
        XCTAssertNil(provider.request)
    }

    func testMalformedResponseMissingPrecisionAndRPCFailureReachOperationResult() throws {
        for precision in [Int16(2), nil] {
            let provider = CovGWeb3Provider()
            provider.payload = Data(#""0x00""#.utf8)
            let operation = try XCTUnwrap(ChainlinkOperationFactoryImpl().priceCall(for: chainAsset(precision: precision), connection: Web3(provider: provider).eth))
            XCTAssertThrowsError(try CovGOperationFixtures.run(operation))
        }
        let provider = CovGWeb3Provider()
        provider.error = NSError(domain: "CovG.web3", code: 96)
        let operation = try XCTUnwrap(ChainlinkOperationFactoryImpl().priceCall(for: chainAsset(precision: 2), connection: Web3(provider: provider).eth))
        XCTAssertThrowsError(try CovGOperationFixtures.run(operation)) { XCTAssertEqual(($0 as NSError).code, 96) }
    }

    private func chainAsset(precision: Int16?, contract: String? = nil) throws -> ChainAsset {
        let asset = AssetModel(
            id: "0", name: "Token", symbol: "UNIT", precision: 12, isUtility: true, isNative: true,
            priceProvider: PriceProvider(type: .chainlink, id: contract ?? self.contract, precision: precision), coingeckoPriceId: "token"
        )
        return try ChainAsset(chain: CovGOperationFixtures.chain(), asset: asset)
    }
}

private final class CovGWeb3Provider: Web3Provider {
    var payload = Data(#""0x""#.utf8)
    var error: Error?
    var request: [String: Any]?
    func send<Params: Codable, Result: Codable>(request: RPCRequest<Params>, response: @escaping (Web3Response<Result>) -> Void) {
        do {
            self.request = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
            if let error {
                throw error
            }
            let result = try JSONDecoder().decode(Result.self, from: payload)
            response(Web3Response(status: .success(result)))
        } catch { response(Web3Response(error: error)) }
    }
}
