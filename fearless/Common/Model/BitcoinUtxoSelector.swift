import Foundation

final class BitcoinUtxoSelector {
    static let bitcoinP2wpkhDustSats: Int64 = 330
    static let defaultMaxInputs = 100
    static let maxFeeRateSatPerVbyte = 10000.0
    static let maxSatoshi: Int64 = 2_100_000_000_000_000

    private static let maxUInt32 = Int64(UInt32.max)
    private static let p2wpkhInputVbytes = 68
    private static let p2wpkhOutputVbytes = 31
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

    func select(
        amountSats: Int64,
        changeAddress: String,
        feeRateSatPerVbyte: Double,
        maxInputs: Int = BitcoinUtxoSelector.defaultMaxInputs,
        network: BitcoinIndexerNetwork = .mainnet,
        utxos: [BitcoinSpendableUtxo]
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
        let normalizedUtxos = try normalizeUtxos(utxos)
        var selected: [BitcoinSpendableUtxo] = []
        var total: Int64 = 0

        for utxo in normalizedUtxos.sorted(by: compareUtxos) {
            selected.append(utxo)
            guard selected.count <= maxInputs else {
                throw BitcoinUtxoSelectionError.tooManyInputsRequired
            }
            total = try safeAdd(total, utxo.valueSats)
            guard total <= Self.maxSatoshi else {
                throw BitcoinUtxoSelectionError.satoshiOverflow
            }

            let noChangeFee = try estimateFee(inputCount: selected.count, outputCount: 1, feeRateSatPerVbyte: feeRateSatPerVbyte)
            let noChangeRemainder = total - amountSats - noChangeFee

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

            let withChangeFee = try estimateFee(inputCount: selected.count, outputCount: 2, feeRateSatPerVbyte: feeRateSatPerVbyte)
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

        throw BitcoinUtxoSelectionError.insufficientFunds
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

    private func estimateFee(inputCount: Int, outputCount: Int, feeRateSatPerVbyte: Double) throws -> Int64 {
        let fee = ceil(Double(try estimateP2wpkhTransactionVSize(inputCount: inputCount, outputCount: outputCount)) * feeRateSatPerVbyte)
        guard fee.isFinite, fee > 0, fee <= Double(Int64.max) else {
            throw BitcoinUtxoSelectionError.invalidFeeRate
        }

        return Int64(fee)
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
    case satoshiOverflow
    case tooManyInputsRequired
    case utxosRequired
}
