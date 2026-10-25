import Foundation
import SSFModels

struct JSONExportData {
    let data: String
    let chain: ChainModel
    let cryptoType: CryptoType?
    let fileURL: URL
}
