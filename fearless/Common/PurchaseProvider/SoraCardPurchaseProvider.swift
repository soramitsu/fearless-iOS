import Foundation
import SSFModels
import SCard

final class SoraCardPurchaseProvider: PurchaseProviderProtocol {
    enum Constants {
        static let title = "SORA Card"
        static let icon = R.image.iconSoraCard()
    }

    private var chainName: String?

    func with(chainName: String) -> Self {
        self.chainName = chainName
        return self
    }

    func buildPurchaseActions(asset: AssetModel, address: String) -> [PurchaseAction] {
        return [PurchaseAction(title: Constants.title, url: URL(string: "soracard://exchange")!, icon: Constants.icon!)]
    }
}
