import BigInt
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

final class CovFWcPolkadotRuntimeTests: XCTestCase {
    func testCoderFactoryComesFromTheChainRuntimeOrFailsWithoutOne() async throws {
        let registry = CovFRegistry()
        let provider = WalletConnectPolkadotRuntimeProvider(chainRegistry: registry, operationQueue: OperationQueue())
        let chain = CovFFixtures.asset().chain
        do {
            _ = try await provider.coderFactory(for: chain)
            XCTFail("Expected missing runtime")
        } catch {
            XCTAssertEqual(error as? fearless.RuntimeProviderError, .providerUnavailable)
        }
        let runtime = try CovFFixtures.runtime(path: .activeEra, type: "u32", definitions: #"{"types":{}}"#)
        registry.runtime = runtime
        let factory = try await provider.coderFactory(for: chain)
        XCTAssertTrue((factory as AnyObject) === (runtime.factory as AnyObject))
    }

    func testInclusionFeeSumsFeeDetailsFromPaymentQuery() async throws {
        let registry = CovFRegistry()
        let engine = CovFQueryEngine()
        engine.replies = [["inclusionFee": ["baseFee": "0x64", "lenFee": "0x0a", "adjustedWeightFee": "0x01"]]]
        registry.connection = engine
        let provider = WalletConnectPolkadotRuntimeProvider(chainRegistry: registry, operationQueue: OperationQueue())
        let fee = try await provider.inclusionFee(of: Data([1, 2]), chain: CovFFixtures.asset().chain)
        XCTAssertEqual(fee, 111)
        XCTAssertEqual(engine.methods, [RPCMethod.paymentInfo])
        XCTAssertEqual(engine.parameters.first as? [String], ["0x0102"])
    }

    func testInclusionFeeReportsMissingConnectionAndNodeErrors() async throws {
        let registry = CovFRegistry()
        let provider = WalletConnectPolkadotRuntimeProvider(chainRegistry: registry, operationQueue: OperationQueue())
        let chain = CovFFixtures.asset().chain
        do {
            _ = try await provider.inclusionFee(of: Data([1]), chain: chain)
            XCTFail("Expected missing connection")
        } catch {
            guard case .connectionUnavailable? = error as? ChainRegistryError else {
                return XCTFail("Unexpected \(error)")
            }
        }
        let engine = CovFQueryEngine()
        engine.failure = NSError(domain: "fee", code: 3)
        registry.connection = engine
        do {
            _ = try await provider.inclusionFee(of: Data([1]), chain: chain)
            XCTFail("Expected node error")
        } catch {
            XCTAssertEqual((error as NSError).domain, "fee")
        }
    }
}
