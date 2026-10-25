import Foundation
import UIKit
import SSFModels

struct RestoreJson {
    let data: String
    let chain: ChainModel
    let cryptoType: CryptoType?
    let fileURL: URL
    let accountId: Data?

    init(data: String, chain: ChainModel, cryptoType: CryptoType?, fileURL: URL, accountId: Data? = nil) {
        self.data = data
        self.chain = chain
        self.cryptoType = cryptoType
        self.fileURL = fileURL
        self.accountId = accountId
    }
}
