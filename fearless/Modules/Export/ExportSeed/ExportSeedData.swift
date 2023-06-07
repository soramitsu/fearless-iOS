import Foundation
import SSFModels

struct ExportSeedData {
    let seed: Data
    let derivationPath: String?
    let chain: ChainModel
    let cryptoType: CryptoType
}
