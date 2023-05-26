import UIKit
import SSFUtils

struct ReceiveAssetViewModel {
    let asset: String
    let accountName: String
    let address: String

    init(asset: String, accountName: String, address: String) {
        self.asset = asset
        self.accountName = accountName
        self.address = address
    }
}
