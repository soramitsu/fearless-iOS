import Combine
import Foundation
import RobinHood

class ChainAssetModel: Codable {
    let assetId: String
    let staking: StakingType?
    let purchaseProviders: [PurchaseProvider]?
    var asset: AssetModel!
    var chain: ChainModel!

    var isUtility: Bool { asset.chainId == chain.identifier }

    init(
        assetId: String,
        staking: StakingType? = nil,
        purchaseProviders: [PurchaseProvider]? = nil,
        asset: AssetModel,
        chain: ChainModel
    ) {
        self.assetId = assetId
        self.staking = staking
        self.purchaseProviders = purchaseProviders
        self.asset = asset
        self.chain = chain
    }
}

extension ChainAssetModel: Hashable {
    static func == (lhs: ChainAssetModel, rhs: ChainAssetModel) -> Bool {
        lhs.assetId == rhs.assetId &&
            lhs.asset == rhs.asset &&
            lhs.staking == rhs.staking &&
            lhs.purchaseProviders == rhs.purchaseProviders
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(assetId)
    }
}

enum PurchaseProvider: String, Codable {
    case moonpay
    case ramp
}

enum StakingType: String, Codable {
    case relayChain = "relaychain"
}
