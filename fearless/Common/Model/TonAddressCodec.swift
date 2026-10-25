import CryptoKit
import Foundation

enum TonAddressCodecError: Error, Equatable {
    case invalidPublicKeyLength
    case invalidAccountHashLength
    case invalidCellReference
}

struct TonV4R2AddressSet: Equatable {
    let accountHash: Data
    let bounceable: String
    let nonBounceable: String
    let testnetNonBounceable: String
}

enum TonAddressCodec {
    private static let workchain = 0
    private static let walletId: UInt32 = 698_983_191
    private static let publicKeyLength = 32
    private static let accountHashLength = 32
    private static let cellHashLength = 32
    private static let walletDataCellBitCount = 321
    private static let stateInitCellBitCount = 5
    private static let walletDataTopUpByte: UInt8 = 0x40
    private static let stateInitFlagsWithCodeAndData: UInt8 = 0x34
    private static let walletV4R2CodeDepth = 7
    private static let walletV4R2CodeHash = Data(tonHex: "feb5ff6820e2ff0d9483e7e0d62c817d846789fb4ae580c878866d959dabd5c0")

    static func v4R2Addresses(publicKey: Data) throws -> TonV4R2AddressSet {
        let accountHash = try v4R2AccountHash(publicKey: publicKey)

        return TonV4R2AddressSet(
            accountHash: accountHash,
            bounceable: try friendlyAddress(accountHash: accountHash, isTestnet: false, bounceable: true),
            nonBounceable: try friendlyAddress(accountHash: accountHash, isTestnet: false, bounceable: false),
            testnetNonBounceable: try friendlyAddress(accountHash: accountHash, isTestnet: true, bounceable: false)
        )
    }

    static func v4R2AccountHash(publicKey: Data) throws -> Data {
        guard publicKey.count == publicKeyLength else {
            throw TonAddressCodecError.invalidPublicKeyLength
        }

        var dataCellBytes = Data(repeating: 0, count: 4)
        dataCellBytes.append(walletId.bigEndianBytes)
        dataCellBytes.append(publicKey)
        dataCellBytes.append(walletDataTopUpByte)

        let dataCell = try cellHash(
            bitsCount: walletDataCellBitCount,
            dataWithTopUp: dataCellBytes,
            refs: []
        )

        let stateInitCell = try cellHash(
            bitsCount: stateInitCellBitCount,
            dataWithTopUp: Data([stateInitFlagsWithCodeAndData]),
            refs: [
                CellReference(depth: walletV4R2CodeDepth, hash: walletV4R2CodeHash),
                CellReference(depth: dataCell.depth, hash: dataCell.hash)
            ]
        )

        return stateInitCell.hash
    }

    static func friendlyAddress(
        accountHash: Data,
        isTestnet: Bool,
        bounceable: Bool
    ) throws -> String {
        guard accountHash.count == accountHashLength else {
            throw TonAddressCodecError.invalidAccountHashLength
        }

        var tag: UInt8 = bounceable ? 0x11 : 0x51
        if isTestnet {
            tag |= 0x80
        }

        var payload = Data([tag, UInt8(workchain)])
        payload.append(accountHash)
        payload.append(crc16Xmodem(payload).bigEndianBytes)

        return payload.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func cellHash(
        bitsCount: Int,
        dataWithTopUp: Data,
        refs: [CellReference]
    ) throws -> CellDigest {
        guard refs.count <= 4, refs.allSatisfy({ $0.depth >= 0 && $0.hash.count == cellHashLength }) else {
            throw TonAddressCodecError.invalidCellReference
        }

        let fullBytes = bitsCount / 8
        let ceilBytes = (bitsCount + 7) / 8
        let descriptor = UInt8(fullBytes + ceilBytes)
        var representation = Data([UInt8(refs.count), descriptor])
        representation.append(dataWithTopUp)

        for ref in refs {
            representation.append(UInt16(ref.depth).bigEndianBytes)
        }

        for ref in refs {
            representation.append(ref.hash)
        }

        let hash = Data(SHA256.hash(data: representation))
        let depth = refs.map(\.depth).max().map { $0 + 1 } ?? 0

        return CellDigest(depth: depth, hash: hash)
    }

    private static func crc16Xmodem(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0

        for byte in data {
            crc ^= UInt16(byte) << 8

            for _ in 0 ..< 8 {
                if crc & 0x8000 != 0 {
                    crc = (crc << 1) ^ 0x1021
                } else {
                    crc <<= 1
                }
            }
        }

        return crc
    }
}

private struct CellReference {
    let depth: Int
    let hash: Data
}

private struct CellDigest {
    let depth: Int
    let hash: Data
}

private extension UInt16 {
    var bigEndianBytes: Data {
        var value = bigEndian
        return Data(bytes: &value, count: MemoryLayout<UInt16>.size)
    }
}

private extension UInt32 {
    var bigEndianBytes: Data {
        var value = bigEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}

private extension Data {
    init(tonHex: String) {
        var bytes: [UInt8] = []
        var index = tonHex.startIndex

        while index < tonHex.endIndex {
            let nextIndex = tonHex.index(index, offsetBy: 2)
            bytes.append(UInt8(tonHex[index ..< nextIndex], radix: 16)!)
            index = nextIndex
        }

        self.init(bytes)
    }
}
