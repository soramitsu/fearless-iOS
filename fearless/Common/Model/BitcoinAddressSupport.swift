import CommonCrypto
import Foundation

/// Decides which Bitcoin addresses the wallet can pay and builds their output scripts.
///
/// The wallet's own addresses are native SegWit (P2WPKH, `bc1q…`). It can pay every standard
/// address type in use: legacy `1…` (P2PKH), script `3…` (P2SH), native SegWit `bc1q…`
/// (P2WPKH and P2WSH) and Taproot `bc1p…` (P2TR). Witness versions that Bitcoin has not
/// defined yet are valid addresses the wallet refuses to pay, so no coin goes to a script
/// nobody can spend today.
enum BitcoinAddressSupport {
    enum Kind: Equatable {
        case p2pkh
        case p2sh
        case p2wpkh
        case p2wsh
        case p2tr

        /// Serialized output size: 8-byte value, script length byte, script.
        var outputVbytes: Int {
            switch self {
            case .p2pkh:
                return 34
            case .p2sh:
                return 32
            case .p2wpkh:
                return 31
            case .p2wsh, .p2tr:
                return 43
            }
        }

        /// The smallest amount nodes relay to this output type (Bitcoin Core's dust limit at
        /// the default 3 sat/vB dust relay fee). The wallet keeps its long-standing 330 sat
        /// floor for SegWit outputs.
        var dustSats: Int64 {
            switch self {
            case .p2pkh:
                return 546
            case .p2sh:
                return 540
            case .p2wpkh, .p2wsh, .p2tr:
                return BitcoinUtxoSelector.bitcoinP2wpkhDustSats
            }
        }
    }

    struct Recipient: Equatable {
        /// Canonical spelling: lowercase for bech32, unchanged for base58.
        let address: String
        let kind: Kind
        let scriptPubKey: Data
    }

    enum Classification: Equatable {
        case supported(Recipient)
        /// A well-formed address for this network of a type the wallet cannot pay yet.
        case unsupported
        /// A well-formed Bitcoin address for a different Bitcoin network.
        case wrongNetwork
        case invalid
    }

    static func classify(_ address: String, network: BitcoinKeyDerivation.Network) -> Classification {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= maxAddressLength, trimmed.utf8.allSatisfy({ $0 < 0x80 }) else {
            return .invalid
        }

        if let segwit = decodeSegwit(trimmed) {
            return classify(segwit: segwit, address: trimmed.lowercased(), network: network)
        }
        if let base58 = decodeBase58Check(trimmed) {
            return classify(base58: base58, address: trimmed, network: network)
        }
        return .invalid
    }

    /// The supported recipient for an address, or `nil` for anything the wallet cannot pay.
    static func recipient(_ address: String, network: BitcoinKeyDerivation.Network) -> Recipient? {
        guard case let .supported(recipient) = classify(address, network: network) else {
            return nil
        }
        return recipient
    }

    // MARK: - SegWit (BIP173 bech32, BIP350 bech32m)

    private struct SegwitProgram {
        let hrp: String
        let version: Int
        let program: [UInt8]
    }

    private static func classify(
        segwit: SegwitProgram,
        address: String,
        network: BitcoinKeyDerivation.Network
    ) -> Classification {
        guard segwit.hrp == network.hrp else {
            return knownHrps.contains(segwit.hrp) ? .wrongNetwork : .invalid
        }

        let kind: Kind
        switch (segwit.version, segwit.program.count) {
        case (0, 20):
            kind = .p2wpkh
        case (0, 32):
            kind = .p2wsh
        case (1, 32):
            kind = .p2tr
        default:
            return .unsupported
        }

        let versionOpcode = UInt8(segwit.version == 0 ? 0x00 : 0x50 + segwit.version)
        let script = Data([versionOpcode, UInt8(segwit.program.count)] + segwit.program)
        return .supported(Recipient(address: address, kind: kind, scriptPubKey: script))
    }

    private static func decodeSegwit(_ address: String) -> SegwitProgram? {
        guard address == address.lowercased() || address == address.uppercased() else {
            return nil
        }
        let normalized = Array(address.lowercased().utf8)
        guard
            normalized.count <= 90,
            let separator = normalized.lastIndex(of: UInt8(ascii: "1")),
            separator >= 1,
            normalized.count - separator - 1 >= 7
        else {
            return nil
        }

        let hrpBytes = normalized[..<separator]
        guard hrpBytes.allSatisfy({ (33 ... 126).contains($0) }) else {
            return nil
        }
        var values: [Int] = []
        for character in normalized[(separator + 1)...] {
            guard let value = bech32Alphabet.firstIndex(of: character) else {
                return nil
            }
            values.append(value)
        }

        let checksum = bech32Polymod(expandHrp(hrpBytes) + values)
        let data = Array(values.dropLast(6))
        guard let version = data.first, version <= 16 else {
            return nil
        }
        // BIP350: version 0 uses the original checksum, every later version bech32m. An address
        // with the other checksum is invalid, not a different address.
        guard checksum == (version == 0 ? bech32Constant : bech32mConstant) else {
            return nil
        }
        guard let program = convertBits(Array(data.dropFirst()), from: 5, to: 8), (2 ... 40).contains(program.count) else {
            return nil
        }
        if version == 0, program.count != 20, program.count != 32 {
            return nil
        }

        return SegwitProgram(
            hrp: String(decoding: hrpBytes, as: UTF8.self),
            version: version,
            program: program.map(UInt8.init)
        )
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

    private static func expandHrp(_ hrp: ArraySlice<UInt8>) -> [Int] {
        hrp.map { Int($0) >> 5 } + [0] + hrp.map { Int($0) & 31 }
    }

    /// Regroups bits without padding; fails on leftover non-zero bits or more than four of them.
    private static func convertBits(_ values: [Int], from: Int, to: Int) -> [Int]? {
        var accumulator = 0
        var bits = 0
        let maxValue = (1 << to) - 1
        var result: [Int] = []

        for value in values {
            guard value >= 0, value >> from == 0 else {
                return nil
            }
            accumulator = (accumulator << from) | value
            bits += from
            while bits >= to {
                bits -= to
                result.append((accumulator >> bits) & maxValue)
            }
            accumulator &= (1 << bits) - 1
        }

        guard bits < from, accumulator == 0 else {
            return nil
        }
        return result
    }

    // MARK: - Base58Check (P2PKH, P2SH)

    private struct Base58Payload {
        let version: UInt8
        let hash: [UInt8]
    }

    private static func classify(
        base58: Base58Payload,
        address: String,
        network: BitcoinKeyDerivation.Network
    ) -> Classification {
        let versions = base58Versions(for: network)
        let hash = base58.hash
        if base58.version == versions.p2pkh {
            let script = Data([0x76, 0xA9, 0x14] + hash + [0x88, 0xAC])
            return .supported(Recipient(address: address, kind: .p2pkh, scriptPubKey: script))
        }
        if base58.version == versions.p2sh {
            let script = Data([0xA9, 0x14] + hash + [0x87])
            return .supported(Recipient(address: address, kind: .p2sh, scriptPubKey: script))
        }

        let otherNetworks: [BitcoinKeyDerivation.Network] = [.mainnet, .testnet]
        let isOtherNetwork = otherNetworks.contains { other in
            let otherVersions = base58Versions(for: other)
            return base58.version == otherVersions.p2pkh || base58.version == otherVersions.p2sh
        }
        return isOtherNetwork ? .wrongNetwork : .invalid
    }

    private static func base58Versions(for network: BitcoinKeyDerivation.Network) -> (p2pkh: UInt8, p2sh: UInt8) {
        switch network {
        case .mainnet:
            return (0x00, 0x05)
        case .testnet:
            return (0x6F, 0xC4)
        }
    }

    private static func decodeBase58Check(_ address: String) -> Base58Payload? {
        var digits: [UInt8] = []
        for character in address.utf8 {
            guard let value = base58Alphabet.firstIndex(of: character) else {
                return nil
            }
            var carry = value
            for index in digits.indices {
                carry += Int(digits[index]) * 58
                digits[index] = UInt8(carry & 0xFF)
                carry >>= 8
            }
            while carry > 0 {
                digits.append(UInt8(carry & 0xFF))
                carry >>= 8
            }
        }
        let leadingZeros = address.utf8.prefix { $0 == UInt8(ascii: "1") }.count
        let decoded = [UInt8](repeating: 0, count: leadingZeros) + digits.reversed()

        guard decoded.count == 25 else {
            return nil
        }
        let payload = Array(decoded.prefix(21))
        guard Array(sha256(sha256(payload)).prefix(4)) == Array(decoded.suffix(4)) else {
            return nil
        }

        return Base58Payload(version: payload[0], hash: Array(payload.dropFirst()))
    }

    private static func sha256(_ bytes: [UInt8]) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = CC_SHA256(bytes, CC_LONG(bytes.count), &output)
        return output
    }

    private static let maxAddressLength = 90
    private static let knownHrps: Set<String> = ["bc", "tb", "bcrt"]
    private static let bech32Constant = 1
    private static let bech32mConstant = 0x2BC8_30A3
    private static let bech32Alphabet = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l".utf8)
    private static let base58Alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
    private static let bech32Generators = [
        0x3B6A_57B2,
        0x2650_8E6D,
        0x1EA1_19FA,
        0x3D42_33DD,
        0x2A14_62B3
    ]
}
