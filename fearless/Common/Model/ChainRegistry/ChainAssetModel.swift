import Combine
import Foundation
import RobinHood
import SSFModels

class ChainAssetModel: Codable {
    let assetId: String
    let staking: RawStakingType?
    let purchaseProviders: [PurchaseProvider]?
    let type: ChainAssetType
    let isUtility: Bool
    let isNative: Bool

    var asset: AssetModel!
    weak var chain: ChainModel?

    init(
        assetId: String,
        staking: RawStakingType? = nil,
        purchaseProviders: [PurchaseProvider]? = nil,
        type: ChainAssetType,
        asset: AssetModel,
        chain: ChainModel,
        isUtility: Bool,
        isNative: Bool
    ) {
        self.assetId = assetId
        self.staking = staking
        self.purchaseProviders = purchaseProviders
        self.type = type
        self.asset = asset
        self.chain = chain
        self.isUtility = isUtility
        self.isNative = isNative
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        assetId = try container.decode(String.self, forKey: .assetId)
        staking = try? container.decode(RawStakingType.self, forKey: .staking)
        purchaseProviders = try? container.decode([PurchaseProvider]?.self, forKey: .purchaseProviders)
        let type = try? container.decode(ChainAssetType?.self, forKey: .type)
        self.type = type ?? ChainAssetType.normal

        isUtility = (try? container.decode(Bool?.self, forKey: .isUtility)) ?? false
        isNative = (try? container.decode(Bool?.self, forKey: .isNative)) ?? false
    }
}

extension ChainAssetModel: Hashable {
    static func == (lhs: ChainAssetModel, rhs: ChainAssetModel) -> Bool {
        lhs.assetId == rhs.assetId &&
            lhs.asset == rhs.asset &&
            lhs.staking == rhs.staking &&
            lhs.purchaseProviders == rhs.purchaseProviders &&
            lhs.type == rhs.type &&
            lhs.isUtility == rhs.isUtility &&
            lhs.isNative == rhs.isNative
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(assetId)
    }
}
