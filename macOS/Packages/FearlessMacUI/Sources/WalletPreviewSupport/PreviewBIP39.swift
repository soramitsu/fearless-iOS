import CryptoKit
import Foundation
import WalletCore

/// BIP-39 for the preview: the English word list, checksum validation and
/// phrases made from fixed, published test entropy. The phrases the preview
/// "generates" are public test vectors and must never hold funds.
enum PreviewBIP39 {
    static let words: [String] = {
        guard let url = Bundle.module.url(forResource: "bip39-english", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        return text.split(whereSeparator: \.isNewline).map(String.init)
    }()

    private static let index: [String: Int] = {
        var result: [String: Int] = [:]
        for (position, word) in words.enumerated() { result[word] = position }
        return result
    }()

    /// Published test entropy per phrase length (Trezor's BIP-39 vectors for
    /// 12, 18 and 24 words; a fixed pattern for 15 and 21).
    static func testEntropy(for length: MnemonicLength) -> [UInt8] {
        let hex: String
        switch length {
        case .words12: hex = "9e885d952ad362caeb4efe34a8e91bd2"
        case .words15: hex = "0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c"
        case .words18: hex = "6610b25967cdcca9d59875f5cb50b0ea75433311869e930b"
        case .words21: hex = "0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4"
        case .words24: hex = "15da872c95a13dd738fbf50e427583ad61f18fd99f628c417a61cf8343c90419"
        }
        return bytes(fromHex: hex)
    }

    static func bytes(fromHex hex: String) -> [UInt8] {
        var result: [UInt8] = []
        var iterator = hex.makeIterator()
        while let high = iterator.next(), let low = iterator.next() {
            if let byte = UInt8(String([high, low]), radix: 16) { result.append(byte) }
        }
        return result
    }

    static func mnemonic(fromEntropy entropy: [UInt8]) -> [String] {
        guard words.count == 2048, [16, 20, 24, 28, 32].contains(entropy.count) else { return [] }
        let checksumBits = entropy.count * 8 / 32
        let hash = Array(SHA256.hash(data: Data(entropy)))
        var bits: [Bool] = []
        bits.reserveCapacity(entropy.count * 8 + checksumBits)
        for byte in entropy {
            for shift in stride(from: 7, through: 0, by: -1) { bits.append((byte >> UInt8(shift)) & 1 == 1) }
        }
        for position in 0..<checksumBits {
            bits.append((hash[position / 8] >> UInt8(7 - position % 8)) & 1 == 1)
        }
        var result: [String] = []
        for chunk in stride(from: 0, to: bits.count, by: 11) {
            var value = 0
            for bit in bits[chunk..<chunk + 11] { value = value << 1 | (bit ? 1 : 0) }
            result.append(words[value])
        }
        return result
    }

    static func validate(_ phrase: [String]) -> MnemonicValidation {
        let normalized = phrase.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard MnemonicLength(rawValue: normalized.count) != nil else {
            return .invalidLength(count: normalized.count)
        }
        let unknown = normalized.indices.filter { index[normalized[$0]] == nil }
        guard unknown.isEmpty else { return .unknownWords(indices: unknown) }
        var bits: [Bool] = []
        for word in normalized {
            let value = index[word] ?? 0
            for shift in stride(from: 10, through: 0, by: -1) { bits.append((value >> shift) & 1 == 1) }
        }
        let checksumBits = bits.count / 33
        let entropyBits = bits.count - checksumBits
        var entropy: [UInt8] = []
        for chunk in stride(from: 0, to: entropyBits, by: 8) {
            var byte: UInt8 = 0
            for bit in bits[chunk..<chunk + 8] { byte = byte << 1 | (bit ? 1 : 0) }
            entropy.append(byte)
        }
        let hash = Array(SHA256.hash(data: Data(entropy)))
        for position in 0..<checksumBits {
            let expected = (hash[position / 8] >> UInt8(7 - position % 8)) & 1 == 1
            if bits[entropyBits + position] != expected { return .invalidChecksum }
        }
        return .valid
    }
}
