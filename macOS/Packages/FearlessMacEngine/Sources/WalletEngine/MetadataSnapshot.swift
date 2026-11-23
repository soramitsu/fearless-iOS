import CryptoKit
import Foundation
import SSFModels
import WalletCore

/// These captures are usable only after the node identifies the exact runtime that produced them.
struct MetadataSnapshot: Decodable {
    let genesis, codeHash, file, sha256: String
    let specVersion, transactionVersion: UInt32

    static let all: [Self] = {
        guard let url = Bundle.module.url(forResource: "metadata-snapshots", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Self].self, from: data)) ?? []
    }()

    func bytes(for runtimeHash: String) throws -> Data {
        guard runtimeHash.lowercased() == codeHash,
              let url = Bundle.module.url(forResource: file, withExtension: nil) else {
            throw WalletError.network("Bundled metadata does not match this runtime.")
        }
        let bytes = try NSData(contentsOf: url).decompressed(using: .zlib) as Data
        guard Data(SHA256.hash(data: bytes)).toHex() == sha256 else {
            throw WalletError.storage("Bundled runtime metadata failed verification.")
        }
        return bytes
    }
}
