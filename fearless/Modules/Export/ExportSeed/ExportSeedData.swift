import Foundation
import SSFModels

struct ExportSeedData {
    let seed: Data
    let derivationPath: String?
    let chain: ChainModel
    let cryptoType: CryptoType
}

/// An account whose raw seed the export does not show, and why
/// (`VerifiedSeedExportError` for a seed that is missing or would restore another address).
struct ExportSeedNotShown {
    let chain: ChainModel
    let error: Error
}
