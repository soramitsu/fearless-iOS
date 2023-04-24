import Foundation
import FearlessUtils

protocol ChainStakingSettings {
    var rewardAssetName: String? { get }

    func accountIdParam(accountId: AccountId) -> MultiAddress
}

struct DefaultRelaychainChainStakingSettings: ChainStakingSettings {
    var rewardAssetName: String? {
        nil
    }

    func accountIdParam(accountId: AccountId) -> MultiAddress {
        .accoundId(accountId)
    }
}

struct SoraChainStakingSettings: ChainStakingSettings {
    var rewardAssetName: String? {
        "val"
    }

    func accountIdParam(accountId: AccountId) -> MultiAddress {
        .accountTo(accountId)
    }
}
