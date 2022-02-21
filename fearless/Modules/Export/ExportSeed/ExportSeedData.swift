import Foundation

struct ExportSeedData {
    let seed: Data
    let derivationPath: String?
    let chain: ChainModel
    let cryptoType: CryptoType
}
