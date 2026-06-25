import XCTest
@testable import fearless

final class BitcoinFeeEstimatorTests: XCTestCase {
    func testSelectsExactNextSlowerOrSlowestAvailableFeeEstimate() throws {
        let estimator = BitcoinFeeEstimator(client: FakeBitcoinIndexerClient())

        XCTAssertEqual(
            try estimator.select(estimates: ["1": 9, "2": 4, "6": 2], targetBlocks: 2).feeRateSatPerVbyte,
            4
        )
        XCTAssertEqual(
            try estimator.select(estimates: ["1": 9, "6": 2], targetBlocks: 2).feeRateSatPerVbyte,
            2
        )
        XCTAssertEqual(
            try estimator.select(estimates: ["1": 9, "6": 2], targetBlocks: 10).feeRateSatPerVbyte,
            2
        )
    }

    func testRejectsUnsafeFeeEstimatesAndTargets() {
        let estimator = BitcoinFeeEstimator(client: FakeBitcoinIndexerClient())

        assertFeeError(.feeEstimatesUnavailable) {
            _ = try estimator.select(estimates: [:], targetBlocks: 2)
        }
        assertFeeError(.invalidFeeTarget) {
            _ = try estimator.select(estimates: ["2": 1], targetBlocks: 0)
        }
        assertFeeError(.invalidFeeRate) {
            _ = try estimator.select(estimates: ["2": 10_001], targetBlocks: 2)
        }
    }

    func testFetchesEstimatesThroughSelectedBitcoinIndexerNetwork() async throws {
        let client = FakeBitcoinIndexerClient(estimates: ["3": 5])
        let estimator = BitcoinFeeEstimator(client: client)

        let result = try await estimator.estimate(
            network: .testnet,
            baseURL: "https://bitcoin.example/api",
            targetBlocks: 2
        )

        XCTAssertEqual(result.feeRateSatPerVbyte, 5)
        XCTAssertEqual(result.requestedTargetBlocks, 2)
        XCTAssertEqual(result.selectedTargetBlocks, 3)
        XCTAssertEqual(client.lastNetwork, .testnet)
        XCTAssertEqual(client.lastBaseURL, "https://bitcoin.example/api")
    }

    private func assertFeeError(
        _ expected: BitcoinFeeEstimatorError,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () throws -> Void
    ) {
        do {
            try block()
            XCTFail("Expected Bitcoin fee estimator error \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? BitcoinFeeEstimatorError, expected, file: file, line: line)
        }
    }

    private final class FakeBitcoinIndexerClient: BitcoinIndexerClientProtocol {
        private let estimates: [String: Double]
        private(set) var lastNetwork: BitcoinIndexerNetwork?
        private(set) var lastBaseURL: String?

        init(estimates: [String: Double] = [:]) {
            self.estimates = estimates
        }

        func feeEstimates(
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> [String: Double] {
            lastNetwork = network
            lastBaseURL = baseURL
            return estimates
        }

        func address(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> BitcoinEsploraAddress {
            throw UnexpectedEndpointError()
        }

        func utxos(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> [BitcoinEsploraUtxo] {
            throw UnexpectedEndpointError()
        }

        func transactions(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?,
            lastSeenTxid: String?,
            mempool: Bool
        ) async throws -> [BitcoinEsploraTransaction] {
            throw UnexpectedEndpointError()
        }

        func broadcastTransaction(
            txHex: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> String {
            throw UnexpectedEndpointError()
        }
    }

    private struct UnexpectedEndpointError: Error {}
}
