import Foundation

final class BitcoinSendPlanner {
    private let client: BitcoinIndexerClientProtocol
    private let feeEstimator: BitcoinFeeEstimator
    private let utxoSelector: BitcoinUtxoSelector

    init(
        client: BitcoinIndexerClientProtocol,
        feeEstimator: BitcoinFeeEstimator? = nil,
        utxoSelector: BitcoinUtxoSelector = BitcoinUtxoSelector()
    ) {
        self.client = client
        self.feeEstimator = feeEstimator ?? BitcoinFeeEstimator(client: client)
        self.utxoSelector = utxoSelector
    }

    func plan(
        amountSats: Int64,
        sources: [BitcoinUtxoSource],
        recipientAddress: String,
        changeAddress: String? = nil,
        feeRateSatPerVbyte: Double? = nil,
        feeTargetBlocks: Int = BitcoinFeeEstimator.defaultTargetBlocks,
        includeUnconfirmed: Bool = false,
        maxInputs: Int = BitcoinUtxoSelector.defaultMaxInputs,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) async throws -> BitcoinSendPlan {
        let normalizedSources = try normalizeSources(sources, network: network)
        let normalizedRecipient = try normalizeAddress(
            recipientAddress,
            network: network,
            error: .invalidRecipientAddress
        )
        let normalizedChange = try normalizeAddress(
            changeAddress ?? normalizedSources[0].address,
            network: network,
            error: .invalidChangeAddress
        )
        let resolvedFeeRate: Double
        if let feeRateSatPerVbyte {
            resolvedFeeRate = feeRateSatPerVbyte
        } else {
            resolvedFeeRate = try await feeEstimator.estimate(
                network: network,
                baseURL: baseURL,
                targetBlocks: feeTargetBlocks
            ).feeRateSatPerVbyte
        }
        try validateFeeRate(resolvedFeeRate)

        let spendableUtxos = try await normalizedSources.asyncFlatMap { source in
            try utxoSelector.spendableUtxos(
                source: source,
                utxos: try await client.utxos(address: source.address, network: network, baseURL: baseURL),
                network: network,
                includeUnconfirmed: includeUnconfirmed
            )
        }

        guard !spendableUtxos.isEmpty else {
            throw BitcoinSendPlannerError.noSpendableUtxos
        }

        let selection = try utxoSelector.select(
            amountSats: amountSats,
            changeAddress: normalizedChange,
            feeRateSatPerVbyte: resolvedFeeRate,
            maxInputs: maxInputs,
            network: network,
            utxos: spendableUtxos
        )

        return BitcoinSendPlan(
            amountSats: amountSats,
            recipientAddress: normalizedRecipient,
            changeAddress: selection.changeAddress,
            feeRateSatPerVbyte: resolvedFeeRate,
            feeTargetBlocks: feeRateSatPerVbyte == nil ? feeTargetBlocks : nil,
            includeUnconfirmed: includeUnconfirmed,
            network: network,
            sourceAddresses: normalizedSources.map(\.address),
            selectedUtxos: selection.selectedUtxos,
            inputTotalSats: selection.inputTotalSats,
            feeSats: selection.feeSats,
            changeSats: selection.changeSats,
            absorbedDustSats: selection.absorbedDustSats
        )
    }

    private func normalizeSources(
        _ sources: [BitcoinUtxoSource],
        network: BitcoinIndexerNetwork
    ) throws -> [BitcoinUtxoSource] {
        guard !sources.isEmpty else {
            throw BitcoinSendPlannerError.sourcesRequired
        }
        guard sources.count <= Self.maxSources else {
            throw BitcoinSendPlannerError.tooManySources
        }
        var seen = Set<String>()

        return try sources.map { source in
            let address = try normalizeAddress(source.address, network: network, error: .invalidSourceAddress)
            if let derivationPath = source.derivationPath {
                try validateDerivationPath(derivationPath)
            }
            guard seen.insert(address.lowercased()).inserted else {
                throw BitcoinSendPlannerError.duplicateSourceAddress
            }

            return BitcoinUtxoSource(address: address, derivationPath: source.derivationPath)
        }
    }

    private func normalizeAddress(
        _ address: String,
        network: BitcoinIndexerNetwork,
        error plannerError: BitcoinSendPlannerError
    ) throws -> String {
        do {
            return try BitcoinIndexerRoutes.normalizeAddress(address, network: network)
        } catch {
            throw plannerError
        }
    }

    private func validateFeeRate(_ feeRateSatPerVbyte: Double) throws {
        guard
            feeRateSatPerVbyte.isFinite,
            feeRateSatPerVbyte > 0,
            feeRateSatPerVbyte <= BitcoinFeeEstimator.maxFeeRateSatPerVbyte
        else {
            throw BitcoinSendPlannerError.invalidFeeRate
        }
    }

    private func validateDerivationPath(_ derivationPath: String) throws {
        guard derivationPath.range(of: "^m(?:/\\d+'?)+$", options: .regularExpression) != nil else {
            throw BitcoinSendPlannerError.invalidDerivationPath
        }
    }

    private static let maxSources = 100
}

struct BitcoinSendPlan: Equatable {
    let amountSats: Int64
    let recipientAddress: String
    let changeAddress: String?
    let feeRateSatPerVbyte: Double
    let feeTargetBlocks: Int?
    let includeUnconfirmed: Bool
    let network: BitcoinIndexerNetwork
    let sourceAddresses: [String]
    let selectedUtxos: [BitcoinSpendableUtxo]
    let inputTotalSats: Int64
    let feeSats: Int64
    let changeSats: Int64
    let absorbedDustSats: Int64
}

enum BitcoinSendPlannerError: Error, Equatable {
    case duplicateSourceAddress
    case invalidChangeAddress
    case invalidDerivationPath
    case invalidFeeRate
    case invalidRecipientAddress
    case invalidSourceAddress
    case noSpendableUtxos
    case sourcesRequired
    case tooManySources
}

private extension Array {
    func asyncFlatMap<T>(_ transform: (Element) async throws -> [T]) async throws -> [T] {
        var result: [T] = []
        for element in self {
            result.append(contentsOf: try await transform(element))
        }
        return result
    }
}
