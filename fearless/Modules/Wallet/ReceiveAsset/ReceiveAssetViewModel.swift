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
        accountIcon = try? iconGenerator.generateFromAddress(address)
            .imageWithFillColor(
                R.color.colorWhite()!,
                size: CGSize(width: 32.0, height: 32.0),
                contentScale: UIScreen.main.scale
            )
    }
}
