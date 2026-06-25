import Foundation

final class BitcoinFeeEstimator {
    static let defaultTargetBlocks = 2
    static let maxTargetBlocks = 1008
    static let maxFeeRateSatPerVbyte = 10000.0

    private let client: BitcoinIndexerClientProtocol

    init(client: BitcoinIndexerClientProtocol) {
        self.client = client
    }

    func estimate(
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil,
        targetBlocks: Int = BitcoinFeeEstimator.defaultTargetBlocks
    ) async throws -> BitcoinFeeEstimate {
        try select(
            estimates: try await client.feeEstimates(network: network, baseURL: baseURL),
            targetBlocks: targetBlocks
        )
    }

    func select(
        estimates: [String: Double],
        targetBlocks: Int = BitcoinFeeEstimator.defaultTargetBlocks
    ) throws -> BitcoinFeeEstimate {
        try validateTargetBlocks(targetBlocks)
        let entries = estimates.compactMap { entry -> (blocks: Int, feeRate: Double)? in
            guard let parsedBlocks = Int(entry.key), parsedBlocks > 0, entry.value.isFinite, entry.value > 0 else {
                return nil
            }

            return (parsedBlocks, entry.value)
        }.sorted { $0.blocks < $1.blocks }

        guard !entries.isEmpty else {
            throw BitcoinFeeEstimatorError.feeEstimatesUnavailable
        }

        let selected = entries.first { $0.blocks >= targetBlocks } ?? entries[entries.count - 1]
        try validateFeeRate(selected.feeRate)

        return BitcoinFeeEstimate(
            requestedTargetBlocks: targetBlocks,
            selectedTargetBlocks: selected.blocks,
            feeRateSatPerVbyte: selected.feeRate
        )
    }

    private func validateTargetBlocks(_ targetBlocks: Int) throws {
        guard targetBlocks > 0, targetBlocks <= Self.maxTargetBlocks else {
            throw BitcoinFeeEstimatorError.invalidFeeTarget
        }
    }

    private func validateFeeRate(_ feeRateSatPerVbyte: Double) throws {
        guard
            feeRateSatPerVbyte.isFinite,
            feeRateSatPerVbyte > 0,
            feeRateSatPerVbyte <= Self.maxFeeRateSatPerVbyte
        else {
            throw BitcoinFeeEstimatorError.invalidFeeRate
        }
    }
}

struct BitcoinFeeEstimate: Equatable {
    let requestedTargetBlocks: Int
    let selectedTargetBlocks: Int
    let feeRateSatPerVbyte: Double
}

enum BitcoinFeeEstimatorError: Error, Equatable {
    case invalidFeeTarget
    case invalidFeeRate
    case feeEstimatesUnavailable
}
