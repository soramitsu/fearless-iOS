import CryptoKit
import Foundation
import WalletCore

/// Address text for the preview. It checks format only (length, alphabet,
/// network prefix) and makes up addresses from a hash; nothing here derives
/// a real key, and the made-up addresses do not carry valid checksums.
enum PreviewAddressCodec {
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
    private static let alphabetIndex: [UInt8: Int] = {
        var result: [UInt8: Int] = [:]
        for (index, character) in alphabet.enumerated() { result[character] = index }
        return result
    }()

    static func base58Encode(_ bytes: [UInt8]) -> String {
        let leadingZeros = bytes.prefix(while: { $0 == 0 }).count
        var digits: [Int] = []
        for byte in bytes.dropFirst(leadingZeros) {
            var carry = Int(byte)
            for index in 0..<digits.count {
                carry += digits[index] << 8
                digits[index] = carry % 58
                carry /= 58
            }
            while carry > 0 {
                digits.append(carry % 58)
                carry /= 58
            }
        }
        var output = Array(repeating: alphabet[0], count: leadingZeros)
        for digit in digits.reversed() {
            output.append(alphabet[digit])
        }
        return String(decoding: output, as: UTF8.self)
    }

    static func base58Decode(_ text: String) -> [UInt8]? {
        let leadingOnes = text.utf8.prefix(while: { $0 == alphabet[0] }).count
        var bytes: [Int] = []
        for character in text.utf8.dropFirst(leadingOnes) {
            guard let value = alphabetIndex[character] else { return nil }
            var carry = value
            for index in 0..<bytes.count {
                carry += bytes[index] * 58
                bytes[index] = carry & 0xFF
                carry >>= 8
            }
            while carry > 0 {
                bytes.append(carry & 0xFF)
                carry >>= 8
            }
        }
        return Array(repeating: UInt8(0), count: leadingOnes) + bytes.reversed().map { UInt8($0) }
    }

    /// SS58 network prefix of an address-shaped string, or nil.
    static func ss58Prefix(of address: String) -> UInt16? {
        guard (46...49).contains(address.count), let bytes = base58Decode(address), bytes.count == 35 else { return nil }
        return UInt16(bytes[0])
    }

    static func isEVMAddress(_ address: String) -> Bool {
        guard address.count == 42, address.hasPrefix("0x") else { return false }
        return address.dropFirst(2).allSatisfy(\.isHexDigit)
    }

    /// A made-up Substrate address with the right prefix for a network.
    static func fakeSubstrateAddress(seed: Data, prefix: UInt16) -> String {
        let key = Array(SHA256.hash(data: seed))
        return base58Encode([UInt8(truncatingIfNeeded: prefix)] + key + [0x50, 0x56])
    }

    /// The same 32 bytes shown for another network prefix.
    static func reencode(_ address: String, prefix: UInt16) -> String? {
        guard let bytes = base58Decode(address), bytes.count == 35 else { return nil }
        return base58Encode([UInt8(truncatingIfNeeded: prefix)] + bytes[1...])
    }

    static func fakeEVMAddress(seed: Data) -> String {
        let digest = SHA256.hash(data: seed + Data("evm".utf8))
        return "0x" + digest.prefix(20).map { String(format: "%02x", $0) }.joined()
    }

    static func networkName(forPrefix prefix: UInt16) -> String {
        switch prefix {
        case 0: return "Polkadot"
        case 2: return "Kusama"
        case 42: return "Westend or generic Substrate"
        default: return "another Substrate network"
        }
    }

    static func validate(_ rawAddress: String, on chain: Chain) -> RecipientValidation {
        let address = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else { return .empty }
        switch chain.ecosystem {
        case .evm:
            if isEVMAddress(address) { return .valid(normalized: address) }
            if ss58Prefix(of: address) != nil {
                return .wrongNetwork(reason: "This is a Polkadot-ecosystem address. \(chain.name) needs an address that starts with 0x.")
            }
            return .invalid(reason: "Enter a \(chain.name) address: 0x followed by 40 characters.")
        case .substrate:
            if isEVMAddress(address) {
                return .wrongNetwork(reason: "This is an Ethereum address. \(chain.name) needs a \(chain.name) address.")
            }
            guard let prefix = ss58Prefix(of: address) else {
                return .invalid(reason: "This is not a valid \(chain.name) address.")
            }
            if prefix == chain.ss58Prefix ?? 42 || prefix == 42 {
                return .valid(normalized: reencode(address, prefix: chain.ss58Prefix ?? 42) ?? address)
            }
            return .wrongNetwork(reason: "This is a \(networkName(forPrefix: prefix)) address. Sending it to \(chain.name) could lose the funds.")
        }
    }
}
