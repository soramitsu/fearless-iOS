import Foundation

final class BitcoinUtxoSelector {
    static let bitcoinP2wpkhDustSats: Int64 = 330
    static let defaultMaxInputs = 100
    static let maxFeeRateSatPerVbyte = 10000.0
    static let maxSatoshi: Int64 = 2_100_000_000_000_000

    private static let maxUInt32 = Int64(UInt32.max)
    static let p2wpkhOutputVbytes = 31
    /// The largest standard output the wallet pays to (P2WSH and P2TR: 8 + 1 + 34 bytes).
    static let maxRecipientOutputVbytes = 43

    private static let p2wpkhInputVbytes = 68
    private static let txOverheadVbytes = 11

    func spendableUtxos(
        source: BitcoinUtxoSource,
        utxos: [BitcoinEsploraUtxo],
        network: BitcoinIndexerNetwork = .mainnet,
        includeUnconfirmed: Bool = false
    ) throws -> [BitcoinSpendableUtxo] {
        let address: String
        do {
            address = try BitcoinIndexerRoutes.normalizeAddress(source.address, network: network)
        } catch {
            throw BitcoinUtxoSelectionError.invalidSourceAddress
        }
        if let derivationPath = source.derivationPath {
            try validateDerivationPath(derivationPath)
        }

        return utxos
            .filter { includeUnconfirmed || $0.status.confirmed }
            .map {
                BitcoinSpendableUtxo(
                    address: address,
                    derivationPath: source.derivationPath,
                    txid: $0.txid,
                    valueSats: $0.value,
                    vout: $0.vout
                )
            }
    }

    /// Picks inputs largest first. `requiredOutpoints` are spent no matter what: a payment that
    /// replaces an unresolved transfer must reuse that transfer's coins, so that the two
    /// conflict and at most one of them can ever confirm.
    func select(
        amountSats: Int64,
        changeAddress: String,
        feeRateSatPerVbyte: Double,
        maxInputs: Int = BitcoinUtxoSelector.defaultMaxInputs,
        network: BitcoinIndexerNetwork = .mainnet,
        utxos: [BitcoinSpendableUtxo],
        requiredOutpoints: [BitcoinOutpoint] = [],
        recipientOutputVbytes: Int = BitcoinUtxoSelector.p2wpkhOutputVbytes
    ) throws -> BitcoinUtxoSelectionResult {
        try validateAmount(amountSats)
        let normalizedChangeAddress: String
        do {
            normalizedChangeAddress = try BitcoinIndexerRoutes.normalizeAddress(changeAddress, network: network)
        } catch {
            throw BitcoinUtxoSelectionError.invalidChangeAddress
        }
        try validateFeeRate(feeRateSatPerVbyte)
        try validateMaxInputs(maxInputs)
        try validateRecipientOutputVbytes(recipientOutputVbytes)
        let normalizedUtxos = try normalizeUtxos(utxos)
        let required = Set(requiredOutpoints.map(\.normalized))
        let requiredUtxos = normalizedUtxos.filter { required.contains($0.outpoint) }
        guard requiredUtxos.count == required.count else {
            throw BitcoinUtxoSelectionError.requiredInputUnavailable
        }
        let candidates = requiredUtxos.sorted(by: compareUtxos) +
            normalizedUtxos.filter { !required.contains($0.outpoint) }.sorted(by: compareUtxos)
        var selected: [BitcoinSpendableUtxo] = []
        var total: Int64 = 0
        var noChangeRemainder: Int64 = 0
        var noChangeFee: Int64 = 0

        for utxo in candidates {
            selected.append(utxo)
            guard selected.count <= maxInputs else {
                throw BitcoinUtxoSelectionError.tooManyInputsRequired
            }
            total = try safeAdd(total, utxo.valueSats)
            guard total <= Self.maxSatoshi else {
                throw BitcoinUtxoSelectionError.satoshiOverflow
            }
            guard selected.count >= requiredUtxos.count else {
                continue
            }

            noChangeFee = try estimateFee(
                inputCount: selected.count,
                changeOutput: false,
                recipientOutputVbytes: recipientOutputVbytes,
                feeRateSatPerVbyte: feeRateSatPerVbyte
            )
            noChangeRemainder = total - amountSats - noChangeFee

            if noChangeRemainder == 0 {
                return BitcoinUtxoSelectionResult(
                    selectedUtxos: selected,
                    inputTotalSats: total,
                    feeSats: noChangeFee,
                    changeAddress: nil,
                    changeSats: 0,
                    absorbedDustSats: 0
                )
            }

            if noChangeRemainder > 0, noChangeRemainder < Self.bitcoinP2wpkhDustSats {
                return BitcoinUtxoSelectionResult(
                    selectedUtxos: selected,
                    inputTotalSats: total,
                    feeSats: try safeAdd(noChangeFee, noChangeRemainder),
                    changeAddress: nil,
                    changeSats: 0,
                    absorbedDustSats: noChangeRemainder
                )
            }

            let withChangeFee = try estimateFee(
                inputCount: selected.count,
                changeOutput: true,
                recipientOutputVbytes: recipientOutputVbytes,
                feeRateSatPerVbyte: feeRateSatPerVbyte
            )
            let change = total - amountSats - withChangeFee

            if change >= Self.bitcoinP2wpkhDustSats {
                return BitcoinUtxoSelectionResult(
                    selectedUtxos: selected,
                    inputTotalSats: total,
                    feeSats: withChangeFee,
                    changeAddress: normalizedChangeAddress,
                    changeSats: change,
                    absorbedDustSats: 0
                )
            }
        }

        // Every coin is selected and what is left after the amount and the fee is too small to
        // be worth a change output. Paying it as fee is the only valid transaction for this
        // amount; the overpay is bounded by what a change output would have cost plus dust.
        let maxAbsorbedRemainder = Int64(ceil(Double(Self.p2wpkhOutputVbytes) * feeRateSatPerVbyte)) +
            Self.bitcoinP2wpkhDustSats
        if selected.count >= requiredUtxos.count, !selected.isEmpty,
           noChangeRemainder > 0, noChangeRemainder <= maxAbsorbedRemainder {
            return BitcoinUtxoSelectionResult(
                selectedUtxos: selected,
                inputTotalSats: total,
                feeSats: try safeAdd(noChangeFee, noChangeRemainder),
                changeAddress: nil,
                changeSats: 0,
                absorbedDustSats: noChangeRemainder
            )
        }

        throw BitcoinUtxoSelectionError.insufficientFunds
    }

    /// The most that can be sent in one transaction: every coin as an input and one output.
    func sweep(
        feeRateSatPerVbyte: Double,
        maxInputs: Int = BitcoinUtxoSelector.defaultMaxInputs,
        utxos: [BitcoinSpendableUtxo],
        recipientOutputVbytes: Int = BitcoinUtxoSelector.p2wpkhOutputVbytes
    ) throws -> BitcoinSweepEstimate {
        try validateFeeRate(feeRateSatPerVbyte)
        try validateMaxInputs(maxInputs)
        try validateRecipientOutputVbytes(recipientOutputVbytes)
        let inputs = Array(try normalizeUtxos(utxos).sorted(by: compareUtxos).prefix(maxInputs))
        let total = try inputs.reduce(Int64(0)) { try safeAdd($0, $1.valueSats) }
        guard total <= Self.maxSatoshi else {
            throw BitcoinUtxoSelectionError.satoshiOverflow
        }
        let fee = try estimateFee(
            inputCount: inputs.count,
            changeOutput: false,
            recipientOutputVbytes: recipientOutputVbytes,
            feeRateSatPerVbyte: feeRateSatPerVbyte
        )

        return BitcoinSweepEstimate(inputTotalSats: total, feeSats: fee, inputCount: inputs.count)
    }

    func estimateP2wpkhTransactionVSize(inputCount: Int, outputCount: Int) throws -> Int {
        guard inputCount > 0 else {
            throw BitcoinUtxoSelectionError.invalidInputCount
        }
        guard outputCount > 0 else {
            throw BitcoinUtxoSelectionError.invalidOutputCount
        }

        return Self.txOverheadVbytes + inputCount * Self.p2wpkhInputVbytes + outputCount * Self.p2wpkhOutputVbytes
    }

    private func normalizeUtxos(_ utxos: [BitcoinSpendableUtxo]) throws -> [BitcoinSpendableUtxo] {
        guard !utxos.isEmpty else {
            throw BitcoinUtxoSelectionError.utxosRequired
        }
        var outpoints = Set<String>()

        return try utxos.map { utxo in
            let normalizedTxid = utxo.txid.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard normalizedTxid.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
                throw BitcoinUtxoSelectionError.invalidTxid
            }
            guard utxo.vout >= 0, utxo.vout <= Self.maxUInt32 else {
                throw BitcoinUtxoSelectionError.invalidVout
            }
            guard utxo.valueSats > 0, utxo.valueSats <= Self.maxSatoshi else {
                throw BitcoinUtxoSelectionError.invalidUtxoValue
            }
            if let scriptPubKey = utxo.scriptPubKey {
                try validateScriptPubKey(scriptPubKey)
            }
            if let derivationPath = utxo.derivationPath {
                try validateDerivationPath(derivationPath)
            }

            let outpoint = "\(normalizedTxid):\(utxo.vout)"
            guard outpoints.insert(outpoint).inserted else {
                throw BitcoinUtxoSelectionError.duplicateUtxo
            }

            return BitcoinSpendableUtxo(
                address: utxo.address,
                derivationPath: utxo.derivationPath,
                scriptPubKey: utxo.scriptPubKey,
                txid: normalizedTxid,
                valueSats: utxo.valueSats,
                vout: utxo.vout
            )
        }
    }

    private func validateAmount(_ amountSats: Int64) throws {
        guard amountSats > 0, amountSats <= Self.maxSatoshi else {
            throw BitcoinUtxoSelectionError.invalidAmount
        }
        guard amountSats >= Self.bitcoinP2wpkhDustSats else {
            throw BitcoinUtxoSelectionError.amountBelowDust
        }
    }

    private func validateFeeRate(_ feeRateSatPerVbyte: Double) throws {
        guard
            feeRateSatPerVbyte.isFinite,
            feeRateSatPerVbyte > 0,
            feeRateSatPerVbyte <= Self.maxFeeRateSatPerVbyte
        else {
            throw BitcoinUtxoSelectionError.invalidFeeRate
        }
    }

    private func validateMaxInputs(_ maxInputs: Int) throws {
        guard maxInputs > 0, maxInputs <= Self.defaultMaxInputs else {
            throw BitcoinUtxoSelectionError.invalidMaxInputs
        }
    }

    private func validateScriptPubKey(_ scriptPubKey: String) throws {
        guard scriptPubKey.trimmingCharacters(in: .whitespacesAndNewlines).range(
            of: "^(?:[0-9a-fA-F]{2})+$",
            options: .regularExpression
        ) != nil else {
            throw BitcoinUtxoSelectionError.invalidScriptPubKey
        }
    }

    private func validateDerivationPath(_ derivationPath: String) throws {
        guard derivationPath.range(of: "^m(?:/\\d+'?)+$", options: .regularExpression) != nil else {
            throw BitcoinUtxoSelectionError.invalidDerivationPath
        }
    }

    /// Fee for P2WPKH inputs, one recipient output of the given size and an optional P2WPKH
    /// change output. Sizing the recipient output by its real script keeps the paid rate at
    /// the quoted rate for every address type, so a transaction priced at the relay floor is
    /// not pushed below it by a larger output.
    private func estimateFee(
        inputCount: Int,
        changeOutput: Bool,
        recipientOutputVbytes: Int,
        feeRateSatPerVbyte: Double
    ) throws -> Int64 {
        let vsize = try estimateP2wpkhTransactionVSize(inputCount: inputCount, outputCount: changeOutput ? 2 : 1) -
            Self.p2wpkhOutputVbytes + recipientOutputVbytes
        let fee = ceil(Double(vsize) * feeRateSatPerVbyte)
        guard fee.isFinite, fee > 0, fee <= Double(Int64.max) else {
            throw BitcoinUtxoSelectionError.invalidFeeRate
        }

        return Int64(fee)
    }

    private func validateRecipientOutputVbytes(_ vbytes: Int) throws {
        guard vbytes >= Self.p2wpkhOutputVbytes, vbytes <= Self.maxRecipientOutputVbytes else {
            throw BitcoinUtxoSelectionError.invalidOutputCount
        }
    }

    private func safeAdd(_ left: Int64, _ right: Int64) throws -> Int64 {
        let sum = left.addingReportingOverflow(right)
        guard !sum.overflow else {
            throw BitcoinUtxoSelectionError.satoshiOverflow
        }

        return sum.partialValue
    }

    private func compareUtxos(_ left: BitcoinSpendableUtxo, _ right: BitcoinSpendableUtxo) -> Bool {
        if left.valueSats != right.valueSats {
            return left.valueSats > right.valueSats
        }
        if left.txid.lowercased() != right.txid.lowercased() {
            return left.txid.lowercased() < right.txid.lowercased()
        }

        return left.vout < right.vout
    }
}

/// A transaction output identified by the transaction that created it and its index.
struct BitcoinOutpoint: Codable, Hashable {
    let txid: String
    let vout: Int64

    var normalized: BitcoinOutpoint {
        BitcoinOutpoint(
            txid: txid.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            vout: vout
        )
    }
}

struct BitcoinSweepEstimate: Equatable {
    let inputTotalSats: Int64
    let feeSats: Int64
    let inputCount: Int

    /// What the recipient would get if every coin were sent.
    var maxSendableSats: Int64 {
        max(0, inputTotalSats - feeSats)
    }
}

struct BitcoinUtxoSource: Equatable {
    let address: String
    let derivationPath: String?

    init(address: String, derivationPath: String? = nil) {
        self.address = address
        self.derivationPath = derivationPath
    }
}

struct BitcoinSpendableUtxo: Equatable {
    let address: String?
    let derivationPath: String?
    let scriptPubKey: String?
    let txid: String
    let valueSats: Int64
    let vout: Int64

    init(
        address: String? = nil,
        derivationPath: String? = nil,
        scriptPubKey: String? = nil,
        txid: String,
        valueSats: Int64,
        vout: Int64
    ) {
        self.address = address
        self.derivationPath = derivationPath
        self.scriptPubKey = scriptPubKey
        self.txid = txid
        self.valueSats = valueSats
        self.vout = vout
    }

    var outpoint: BitcoinOutpoint {
        BitcoinOutpoint(txid: txid, vout: vout).normalized
    }
}

struct BitcoinUtxoSelectionResult: Equatable {
    let selectedUtxos: [BitcoinSpendableUtxo]
    let inputTotalSats: Int64
    let feeSats: Int64
    let changeAddress: String?
    let changeSats: Int64
    let absorbedDustSats: Int64
}

enum BitcoinUtxoSelectionError: Error, Equatable {
    case amountBelowDust
    case duplicateUtxo
    case insufficientFunds
    case invalidAmount
    case invalidChangeAddress
    case invalidDerivationPath
    case invalidFeeRate
    case invalidInputCount
    case invalidMaxInputs
    case invalidOutputCount
    case invalidScriptPubKey
    case invalidSourceAddress
    case invalidTxid
    case invalidUtxoValue
    case invalidVout
    case requiredInputUnavailable
    case satoshiOverflow
    case tooManyInputsRequired
    case utxosRequired
}
