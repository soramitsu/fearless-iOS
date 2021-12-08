import UIKit
import FearlessUtils

struct ReceiveAssetViewModel {
    let asset: String
    let accountIcon: UIImage?
    let accountName: String
    let address: String

    init(asset: String, accountName: String, address: String, iconGenerator: IconGenerating) {
        self.asset = asset
        self.accountName = accountName
        self.address = address
        accountIcon = try iconGenerator.generateFromAddress(address)
    }
}
