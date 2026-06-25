import CommonCrypto
import Foundation
import secp256k1

enum BitcoinTransactionBuilder {
    private static let defaultSequence = UInt32.max
    private static let sighashAll: UInt32 = 0x01
    private static let txLocktime: UInt32 = 0
    private static let txVersion: UInt32 = 2
    private static let maxUInt32 = Int64(UInt32.max)
    private static let bech32Alphabet = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")
    private static let bech32Generators = [
        0x3B6A_57B2,
        0x2650_8E6D,
        0x1EA1_19FA,
        0x3D42_33DD,
        0x2A14_62B3
    ]

    static func buildP2wpkhTransaction(
        mnemonic: String,
        passphrase: String = "",
        inputs: [BitcoinSpendableUtxo],
        outputs: [BitcoinPaymentOutput],
        changeAddress: String? = nil,
        feeRateSatPerVbyte: Double? = nil,
        feeSats: Int64? = nil,
        network: BitcoinKeyDerivation.Network = .mainnet
    ) throws -> BitcoinBuiltTransaction {
        let normalizedInputs = try normalizeInputs(inputs)
        let normalizedOutputs = try normalizeOutputs(outputs, network: network)
        let inputTotal = try sumSats(normalizedInputs.map(\.valueSats))
        let outputTotal = try sumSats(normalizedOutputs.map(\.valueSats))
        let fee = try normalizeFee(
            feeSats: feeSats,
            feeRateSatPerVbyte: feeRateSatPerVbyte,
            inputCount: normalizedInputs.count,
            outputCount: normalizedOutputs.count + (changeAddress == nil ? 0 : 1)
        )
        let change = inputTotal - outputTotal - fee

        guard change >= 0 else {
            throw BitcoinTransactionError.insufficientFunds
        }

        var finalOutputs = normalizedOutputs
        if change > 0 {
            guard let changeAddress else {
                throw BitcoinTransactionError.changeAddressRequired
            }
            guard change >= BitcoinUtxoSelector.bitcoinP2wpkhDustSats else {
                throw BitcoinTransactionError.changeBelowDust
            }
            finalOutputs.append(try normalizeOutput(BitcoinPaymentOutput(address: changeAddress, valueSats: change), network: network))
        }

        let signingInputs = try normalizedInputs.map { input in
            let derivationPath: String
            if let inputDerivationPath = input.derivationPath {
                derivationPath = inputDerivationPath
            } else {
                derivationPath = try BitcoinKeyDerivation.getReceivePath(network: network)
            }
            let key: BitcoinKeyDerivation.DerivedKey
            do {
                key = try BitcoinKeyDerivation.deriveKey(
                    mnemonic: mnemonic,
                    passphrase: passphrase,
                    derivationPath: derivationPath,
                    network: network
                )
            } catch BitcoinKeyDerivation.DerivationError.emptyMnemonic {
                throw BitcoinTransactionError.invalidMnemonic
            } catch {
                throw BitcoinTransactionError.invalidDerivationPath
            }

            let witnessScript = try p2wpkhOutputScript(fromAddress: key.address)

            if let address = input.address, address.lowercased() != key.address.lowercased() {
                throw BitcoinTransactionError.utxoAddressMismatch
            }
            if let scriptPubKey = input.scriptPubKey, scriptPubKey.lowercased() != witnessScript.hexString {
                throw BitcoinTransactionError.utxoScriptMismatch
            }

            return BitcoinSigningInput(
                privateKey: key.privateKey,
                publicKey: key.publicKey,
                scriptCode: try p2wpkhScriptCode(fromWitnessScript: witnessScript),
                txid: input.txid,
                valueSats: input.valueSats,
                vout: input.vout
            )
        }
        let serializedOutputs = try finalOutputs.map {
            BitcoinSerializedOutput(script: try p2wpkhOutputScript(fromAddress: $0.address), valueSats: $0.valueSats)
        }
        let witnesses = try signingInputs.map { try signP2wpkhInput(inputs: signingInputs, outputs: serializedOutputs, input: $0) }
        let baseTransaction = try serializeTransaction(inputs: signingInputs, outputs: serializedOutputs)
        let witnessTransaction = try serializeTransaction(inputs: signingInputs, outputs: serializedOutputs, witnesses: witnesses)

        return BitcoinBuiltTransaction(
            changeSats: change,
            feeSats: fee,
            inputTotalSats: inputTotal,
            outputTotalSats: outputTotal,
            txHex: witnessTransaction.hexString,
            txid: Data(doubleSha256(baseTransaction).reversed()).hexString,
            vsize: Int(ceil(Double(baseTransaction.count * 3 + witnessTransaction.count) / 4.0))
        )
    }

    static func estimateP2wpkhTransactionVSize(inputCount: Int, outputCount: Int) throws -> Int {
        try BitcoinUtxoSelector().estimateP2wpkhTransactionVSize(inputCount: inputCount, outputCount: outputCount)
    }

    private static func normalizeInputs(_ inputs: [BitcoinSpendableUtxo]) throws -> [BitcoinSpendableUtxo] {
        guard !inputs.isEmpty else {
            throw BitcoinTransactionError.inputsRequired
        }
        var outpoints = Set<String>()

        return try inputs.map { input in
            let normalizedTxid = input.txid.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard normalizedTxid.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
                throw BitcoinTransactionError.invalidTxid
            }
            guard input.vout >= 0, input.vout <= maxUInt32 else {
                throw BitcoinTransactionError.invalidVout
            }
            guard input.valueSats > 0, input.valueSats <= BitcoinUtxoSelector.maxSatoshi else {
                throw BitcoinTransactionError.invalidUtxoValue
            }
            if let scriptPubKey = input.scriptPubKey {
                guard scriptPubKey.range(of: "^(?:[0-9a-fA-F]{2})+$", options: .regularExpression) != nil else {
                    throw BitcoinTransactionError.invalidScriptPubKey
                }
            }
            if let derivationPath = input.derivationPath {
                guard derivationPath.range(of: "^m(?:/\\d+'?)+$", options: .regularExpression) != nil else {
                    throw BitcoinTransactionError.invalidDerivationPath
                }
            }

            let outpoint = "\(normalizedTxid):\(input.vout)"
            guard outpoints.insert(outpoint).inserted else {
                throw BitcoinTransactionError.duplicateUtxo
            }

            return BitcoinSpendableUtxo(
                address: input.address,
                derivationPath: input.derivationPath,
                scriptPubKey: input.scriptPubKey,
                txid: normalizedTxid,
                valueSats: input.valueSats,
                vout: input.vout
            )
        }
    }

    private static func normalizeOutputs(_ outputs: [BitcoinPaymentOutput], network: BitcoinKeyDerivation.Network) throws -> [BitcoinPaymentOutput] {
        guard !outputs.isEmpty else {
            throw BitcoinTransactionError.outputsRequired
        }

        return try outputs.map { try normalizeOutput($0, network: network) }
    }

    private static func normalizeOutput(_ output: BitcoinPaymentOutput, network: BitcoinKeyDerivation.Network) throws -> BitcoinPaymentOutput {
        let normalizedAddress: String
        do {
            normalizedAddress = try BitcoinIndexerRoutes.normalizeAddress(output.address, network: network.indexerNetwork)
        } catch {
            throw BitcoinTransactionError.invalidOutputAddress
        }
        guard
            output.valueSats >= BitcoinUtxoSelector.bitcoinP2wpkhDustSats,
            output.valueSats <= BitcoinUtxoSelector.maxSatoshi
        else {
            throw BitcoinTransactionError.invalidOutputValue
        }

        return BitcoinPaymentOutput(address: normalizedAddress, valueSats: output.valueSats)
    }

    private static func normalizeFee(
        feeSats: Int64?,
        feeRateSatPerVbyte: Double?,
        inputCount: Int,
        outputCount: Int
    ) throws -> Int64 {
        if let feeSats {
            guard feeSats > 0, feeSats <= BitcoinUtxoSelector.maxSatoshi else {
                throw BitcoinTransactionError.invalidFee
            }

            return feeSats
        }

        guard let feeRateSatPerVbyte else {
            throw BitcoinTransactionError.feeRequired
        }
        guard
            feeRateSatPerVbyte.isFinite,
            feeRateSatPerVbyte > 0,
            feeRateSatPerVbyte <= BitcoinUtxoSelector.maxFeeRateSatPerVbyte
        else {
            throw BitcoinTransactionError.invalidFeeRate
        }

        return Int64(ceil(Double(try estimateP2wpkhTransactionVSize(inputCount: inputCount, outputCount: outputCount)) * feeRateSatPerVbyte))
    }

    private static func signP2wpkhInput(
        inputs: [BitcoinSigningInput],
        outputs: [BitcoinSerializedOutput],
        input: BitcoinSigningInput
    ) throws -> [Data] {
        let sighash = try bip143SignatureHash(inputs: inputs, outputs: outputs, input: input)
        let signature = try secp256k1Sign(sighash: sighash, privateKey: input.privateKey) + Data([UInt8(sighashAll)])

        return [signature, input.publicKey]
    }

    private static func secp256k1Sign(sighash: Data, privateKey: Data) throws -> Data {
        guard sighash.count == 32, privateKey.count == 32 else {
            throw BitcoinTransactionError.signingFailed
        }
        guard let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN)) else {
            throw BitcoinTransactionError.signingFailed
        }
        defer {
            secp256k1_context_destroy(context)
        }

        var signature = secp256k1_ecdsa_signature()
        let signResult = sighash.withUnsafeBytes { sighashBytes in
            privateKey.withUnsafeBytes { privateKeyBytes in
                guard
                    let sighashPointer = sighashBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    let privateKeyPointer = privateKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else {
                    return 0
                }

                return Int(secp256k1_ecdsa_sign(context, &signature, sighashPointer, privateKeyPointer, nil, nil))
            }
        }

        guard signResult != 0 else {
            throw BitcoinTransactionError.signingFailed
        }

        var normalizedSignature = secp256k1_ecdsa_signature()
        secp256k1_ecdsa_signature_normalize(context, &normalizedSignature, &signature)

        var derSignature = [UInt8](repeating: 0, count: 72)
        var derLength = derSignature.count
        let serializeResult = derSignature.withUnsafeMutableBufferPointer { derBuffer in
            withUnsafeMutablePointer(to: &derLength) { derLengthPointer in
                withUnsafePointer(to: &normalizedSignature) { signaturePointer in
                    guard let derPointer = derBuffer.baseAddress else {
                        return 0
                    }

                    return Int(secp256k1_ecdsa_signature_serialize_der(context, derPointer, derLengthPointer, signaturePointer))
                }
            }
        }

        guard serializeResult != 0 else {
            throw BitcoinTransactionError.signingFailed
        }

        return Data(derSignature.prefix(derLength))
    }

    private static func bip143SignatureHash(
        inputs: [BitcoinSigningInput],
        outputs: [BitcoinSerializedOutput],
        input: BitcoinSigningInput
    ) throws -> Data {
        var payload = Data()
        payload.append(uint32LE(txVersion))
        payload.append(doubleSha256(try concat(inputs.map { try serializeOutpoint($0) })))
        payload.append(doubleSha256(concat(inputs.map { _ in uint32LE(defaultSequence) })))
        payload.append(try serializeOutpoint(input))
        payload.append(varSlice(input.scriptCode))
        payload.append(try uint64LE(input.valueSats))
        payload.append(uint32LE(defaultSequence))
        payload.append(doubleSha256(try concat(outputs.map { try serializeOutput($0) })))
        payload.append(uint32LE(txLocktime))
        payload.append(uint32LE(sighashAll))

        return doubleSha256(payload)
    }

    private static func serializeTransaction(
        inputs: [BitcoinSigningInput],
        outputs: [BitcoinSerializedOutput],
        witnesses: [[Data]]? = nil
    ) throws -> Data {
        var transaction = Data()
        transaction.append(uint32LE(txVersion))
        if witnesses != nil {
            transaction.append(contentsOf: [0x00, 0x01])
        }
        transaction.append(varInt(UInt64(inputs.count)))
        transaction.append(try concat(inputs.map { try serializeInput($0) }))
        transaction.append(varInt(UInt64(outputs.count)))
        transaction.append(try concat(outputs.map { try serializeOutput($0) }))
        if let witnesses {
            transaction.append(concat(witnesses.map(serializeWitness)))
        }
        transaction.append(uint32LE(txLocktime))

        return transaction
    }

    private static func serializeInput(_ input: BitcoinSigningInput) throws -> Data {
        var serialized = try serializeOutpoint(input)
        serialized.append(varSlice(Data()))
        serialized.append(uint32LE(defaultSequence))

        return serialized
    }

    private static func serializeOutpoint(_ input: BitcoinSigningInput) throws -> Data {
        var outpoint = try Data(bitcoinHex: input.txid).reversedData()
        outpoint.append(uint32LE(UInt32(input.vout)))

        return outpoint
    }

    private static func serializeOutput(_ output: BitcoinSerializedOutput) throws -> Data {
        var serialized = try uint64LE(output.valueSats)
        serialized.append(varSlice(output.script))

        return serialized
    }

    private static func serializeWitness(_ witness: [Data]) -> Data {
        var serialized = varInt(UInt64(witness.count))
        serialized.append(concat(witness.map(varSlice)))

        return serialized
    }

    private static func p2wpkhOutputScript(fromAddress address: String) throws -> Data {
        let decoded = try bech32Decode(address)
        let program = try Data(convertBits(Array(decoded.words.dropFirst()), fromBits: 5, toBits: 8, pad: false).map(UInt8.init))

        guard decoded.words.first == 0, program.count == 20 else {
            throw BitcoinTransactionError.invalidOutputAddress
        }

        return Data([0x00, 0x14]) + program
    }

    private static func p2wpkhScriptCode(fromWitnessScript witnessScript: Data) throws -> Data {
        guard witnessScript.count == 22, witnessScript.first == 0, witnessScript.dropFirst().first == 0x14 else {
            throw BitcoinTransactionError.utxoScriptMismatch
        }

        return Data([0x76, 0xA9, 0x14]) + witnessScript.suffix(20) + Data([0x88, 0xAC])
    }

    private static func bech32Decode(_ address: String) throws -> Bech32Decoded {
        guard address == address.lowercased() || address == address.uppercased() else {
            throw BitcoinTransactionError.invalidOutputAddress
        }
        let normalized = address.lowercased()
        guard
            let separator = normalized.lastIndex(of: "1"),
            separator != normalized.startIndex,
            normalized.distance(from: separator, to: normalized.endIndex) >= 7
        else {
            throw BitcoinTransactionError.invalidOutputAddress
        }

        let hrp = String(normalized[..<separator])
        let values = try normalized[normalized.index(after: separator)...].map { character -> Int in
            guard let index = bech32Alphabet.firstIndex(of: character) else {
                throw BitcoinTransactionError.invalidOutputAddress
            }

            return index
        }

        guard bech32Polymod(expandHrp(hrp) + values) == 1 else {
            throw BitcoinTransactionError.invalidOutputAddress
        }

        return Bech32Decoded(words: Array(values.dropLast(6)))
    }

    private static func bech32Polymod(_ values: [Int]) -> Int {
        var checksum = 1

        for value in values {
            let top = checksum >> 25
            checksum = ((checksum & 0x1FFFFFF) << 5) ^ value

            for (index, generator) in bech32Generators.enumerated() where ((top >> index) & 1) == 1 {
                checksum ^= generator
            }
        }

        return checksum
    }

    private static func expandHrp(_ hrp: String) -> [Int] {
        hrp.map { Int($0.asciiValue ?? 0) >> 5 } + [0] + hrp.map { Int($0.asciiValue ?? 0) & 31 }
    }

    private static func convertBits(_ values: [Int], fromBits: Int, toBits: Int, pad: Bool) throws -> [Int] {
        var accumulator = 0
        var bits = 0
        let maxValue = (1 << toBits) - 1
        let maxAccumulator = (1 << (fromBits + toBits - 1)) - 1
        var result: [Int] = []

        for value in values {
            guard value >= 0, value >> fromBits == 0 else {
                throw BitcoinTransactionError.invalidOutputAddress
            }
            accumulator = ((accumulator << fromBits) | value) & maxAccumulator
            bits += fromBits

            while bits >= toBits {
                bits -= toBits
                result.append((accumulator >> bits) & maxValue)
            }
        }

        if pad {
            if bits > 0 {
                result.append((accumulator << (toBits - bits)) & maxValue)
            }
        } else if bits >= fromBits || ((accumulator << (toBits - bits)) & maxValue) != 0 {
            throw BitcoinTransactionError.invalidOutputAddress
        }

        return result
    }

    private static func doubleSha256(_ data: Data) -> Data {
        data.sha256().sha256()
    }

    private static func varSlice(_ value: Data) -> Data {
        var serialized = varInt(UInt64(value.count))
        serialized.append(value)

        return serialized
    }

    private static func varInt(_ value: UInt64) -> Data {
        switch value {
        case 0 ..< 0xFD:
            return Data([UInt8(value)])
        case 0xFD ... 0xFFFF:
            return Data([0xFD]) + uint16LE(UInt16(value))
        case 0x10000 ... 0xFFFF_FFFF:
            return Data([0xFE]) + uint32LE(UInt32(value))
        default:
            return Data([0xFF]) + uint64LE(value)
        }
    }

    private static func uint16LE(_ value: UInt16) -> Data {
        var littleEndian = value.littleEndian
        return withUnsafeBytes(of: &littleEndian) { Data($0) }
    }

    private static func uint32LE(_ value: UInt32) -> Data {
        var littleEndian = value.littleEndian
        return withUnsafeBytes(of: &littleEndian) { Data($0) }
    }

    private static func uint64LE(_ value: Int64) throws -> Data {
        guard value >= 0 else {
            throw BitcoinTransactionError.invalidUtxoValue
        }

        return uint64LE(UInt64(value))
    }

    private static func uint64LE(_ value: UInt64) -> Data {
        var littleEndian = value.littleEndian
        return withUnsafeBytes(of: &littleEndian) { Data($0) }
    }

    private static func sumSats(_ values: [Int64]) throws -> Int64 {
        try values.reduce(0) { total, value in
            let sum = total.addingReportingOverflow(value)
            guard !sum.overflow, sum.partialValue <= BitcoinUtxoSelector.maxSatoshi else {
                throw BitcoinTransactionError.satoshiOverflow
            }

            return sum.partialValue
        }
    }

    private static func concat(_ chunks: [Data]) -> Data {
        chunks.reduce(into: Data()) { $0.append($1) }
    }
}

struct BitcoinPaymentOutput: Equatable {
    let address: String
    let valueSats: Int64
}

struct BitcoinBuiltTransaction: Equatable {
    let changeSats: Int64
    let feeSats: Int64
    let inputTotalSats: Int64
    let outputTotalSats: Int64
    let txHex: String
    let txid: String
    let vsize: Int
}

enum BitcoinTransactionError: Error, Equatable {
    case changeAddressRequired
    case changeBelowDust
    case duplicateUtxo
    case feeRequired
    case inputsRequired
    case insufficientFunds
    case invalidDerivationPath
    case invalidFee
    case invalidFeeRate
    case invalidMnemonic
    case invalidOutputAddress
    case invalidOutputValue
    case invalidScriptPubKey
    case invalidTxid
    case invalidUtxoValue
    case invalidVarInt
    case invalidVout
    case outputsRequired
    case satoshiOverflow
    case signingFailed
    case utxoAddressMismatch
    case utxoScriptMismatch
}

private struct BitcoinSigningInput {
    let privateKey: Data
    let publicKey: Data
    let scriptCode: Data
    let txid: String
    let valueSats: Int64
    let vout: Int64
}

private struct BitcoinSerializedOutput {
    let script: Data
    let valueSats: Int64
}

private struct Bech32Decoded {
    let words: [Int]
}

private extension BitcoinKeyDerivation.Network {
    var indexerNetwork: BitcoinIndexerNetwork {
        switch self {
        case .mainnet:
            return .mainnet
        case .testnet:
            return .testnet
        }
    }
}

private extension Data {
    init(bitcoinHex: String) throws {
        guard bitcoinHex.count.isMultiple(of: 2) else {
            throw BitcoinTransactionError.invalidTxid
        }

        var output = Data(capacity: bitcoinHex.count / 2)
        var index = bitcoinHex.startIndex

        while index < bitcoinHex.endIndex {
            let nextIndex = bitcoinHex.index(index, offsetBy: 2)
            guard let byte = UInt8(bitcoinHex[index ..< nextIndex], radix: 16) else {
                throw BitcoinTransactionError.invalidTxid
            }
            output.append(byte)
            index = nextIndex
        }

        self = output
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    func reversedData() -> Data {
        Data(reversed())
    }

    func sha256() -> Data {
        var output = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        withUnsafeBytes { dataBytes in
            _ = CC_SHA256(dataBytes.baseAddress, CC_LONG(count), &output)
        }

        return Data(output)
    }
}
