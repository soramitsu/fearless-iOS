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
        requiredOutpoints: [BitcoinOutpoint] = [],
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) async throws -> BitcoinSendPlan {
        let normalizedSources = try normalizeSources(sources, network: network)
        let recipient = try normalizeRecipient(recipientAddress, network: network)
        if amountSats > 0, amountSats < recipient.kind.dustSats {
            throw BitcoinUtxoSelectionError.amountBelowDust
        }
        let normalizedChange = try normalizeAddress(
            changeAddress ?? normalizedSources[0].address,
            network: network,
            error: .invalidChangeAddress
        )
        let resolvedFeeRate = try await resolveFeeRate(
            feeRateSatPerVbyte,
            feeTargetBlocks: feeTargetBlocks,
            network: network,
            baseURL: baseURL
        )
        let spendableUtxos = try await spendableUtxos(
            sources: normalizedSources,
            includeUnconfirmed: includeUnconfirmed,
            network: network,
            baseURL: baseURL
        )

        guard !spendableUtxos.isEmpty else {
            throw BitcoinSendPlannerError.noSpendableUtxos
        }

        let selection = try utxoSelector.select(
            amountSats: amountSats,
            changeAddress: normalizedChange,
            feeRateSatPerVbyte: resolvedFeeRate,
            maxInputs: maxInputs,
            network: network,
            utxos: spendableUtxos,
            requiredOutpoints: requiredOutpoints,
            recipientOutputVbytes: recipient.kind.outputVbytes
        )

        return BitcoinSendPlan(
            amountSats: amountSats,
            recipientAddress: recipient.address,
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

    /// What sending everything the wallet can spend would cost: every spendable coin in, one
    /// output to the recipient, no change. "Max" needs this fee before it can know the amount.
    func maxSend(
        sources: [BitcoinUtxoSource],
        recipientAddress: String,
        feeRateSatPerVbyte: Double? = nil,
        feeTargetBlocks: Int = BitcoinFeeEstimator.defaultTargetBlocks,
        includeUnconfirmed: Bool = false,
        maxInputs: Int = BitcoinUtxoSelector.defaultMaxInputs,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) async throws -> BitcoinMaxSendQuote {
        let normalizedSources = try normalizeSources(sources, network: network)
        let recipient = try normalizeRecipient(recipientAddress, network: network)
        let resolvedFeeRate = try await resolveFeeRate(
            feeRateSatPerVbyte,
            feeTargetBlocks: feeTargetBlocks,
            network: network,
            baseURL: baseURL
        )
        let spendableUtxos = try await spendableUtxos(
            sources: normalizedSources,
            includeUnconfirmed: includeUnconfirmed,
            network: network,
            baseURL: baseURL
        )
        guard !spendableUtxos.isEmpty else {
            throw BitcoinSendPlannerError.noSpendableUtxos
        }
        let sweep = try utxoSelector.sweep(
            feeRateSatPerVbyte: resolvedFeeRate,
            maxInputs: maxInputs,
            utxos: spendableUtxos,
            recipientOutputVbytes: recipient.kind.outputVbytes
        )

        return BitcoinMaxSendQuote(
            spendableSats: sweep.inputTotalSats,
            feeSats: sweep.feeSats,
            feeRateSatPerVbyte: resolvedFeeRate,
            minimumAmountSats: recipient.kind.dustSats
        )
    }

    private func resolveFeeRate(
        _ feeRateSatPerVbyte: Double?,
        feeTargetBlocks: Int,
        network: BitcoinIndexerNetwork,
        baseURL: String?
    ) async throws -> Double {
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

        return resolvedFeeRate
    }

    private func spendableUtxos(
        sources: [BitcoinUtxoSource],
        includeUnconfirmed: Bool,
        network: BitcoinIndexerNetwork,
        baseURL: String?
    ) async throws -> [BitcoinSpendableUtxo] {
        try await sources.asyncFlatMap { source in
            try utxoSelector.spendableUtxos(
                source: source,
                utxos: try await client.utxos(address: source.address, network: network, baseURL: baseURL),
                network: network,
                includeUnconfirmed: includeUnconfirmed
            )
        }
    }

    /// The recipient may be any address type the wallet can pay; sources and change are the
    /// wallet's own native SegWit addresses.
    private func normalizeRecipient(
        _ address: String,
        network: BitcoinIndexerNetwork
    ) throws -> BitcoinAddressSupport.Recipient {
        let keyNetwork: BitcoinKeyDerivation.Network = network == .mainnet ? .mainnet : .testnet
        switch BitcoinAddressSupport.classify(address, network: keyNetwork) {
        case let .supported(recipient):
            return recipient
        case .unsupported:
            throw BitcoinSendPlannerError.unsupportedRecipientAddress
        case .wrongNetwork, .invalid:
            throw BitcoinSendPlannerError.invalidRecipientAddress
        }
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
            let keyNetwork: BitcoinKeyDerivation.Network = network == .mainnet
                ? .mainnet
                : .testnet
            return try BitcoinTransactionBuilder.normalizeP2wpkhAddress(
                address,
                network: keyNetwork
            )
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

    static let maxSources = 100
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
    case unsupportedRecipientAddress
}

struct BitcoinMaxSendQuote: Equatable {
    /// Confirmed coins the transaction would spend.
    let spendableSats: Int64
    let feeSats: Int64
    let feeRateSatPerVbyte: Double
    /// The recipient output type's dust limit.
    let minimumAmountSats: Int64

    var maxAmountSats: Int64 {
        max(0, spendableSats - feeSats)
    }
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
