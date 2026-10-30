import Foundation
import SSFModels

/// Staking of the Polkadot, Kusama and Westend relays moved to their Asset Hubs (Westend first, Kusama on 7 October
/// 2025, Polkadot on 4 November 2025), and every stake kept its address. The Asset Hub runtime holds `Staking`; the
/// relay chain stays its session and era clock. The boundary is a genesis hash, never a chain name or token symbol.
struct AssetHubStakingRoute: Equatable {
    let relayChainId: ChainModel.Id
    let stakingChainId: ChainModel.Id
    let nativeAssetId: AssetModel.Id

    static let routes = [
        // Polkadot -> Polkadot Asset Hub, DOT
        AssetHubStakingRoute(
            relayChainId: "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
            stakingChainId: "68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f",
            nativeAssetId: "887a17c7-1370-4de0-97dd-5422e294fa75"
        ),
        // Kusama -> Kusama Asset Hub, KSM
        AssetHubStakingRoute(
            relayChainId: "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe",
            stakingChainId: "48239ef607d7928874027a43a67689209727dfb3d3dc5e5b03a39bdc2eda771a",
            nativeAssetId: "1e0c2ec6-935f-49bd-a854-5e12ee6c9f1b"
        ),
        // Westend -> Westend Asset Hub, WND
        AssetHubStakingRoute(
            relayChainId: "e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e",
            stakingChainId: "67f9723393ef76214df0118c34bbbd3dbebc8ed46a10973a8c969d48fe7598c9",
            nativeAssetId: "a3868e1b-922e-42d4-b73e-b41712f0843c"
        )
    ]

    static func staking(on chainId: ChainModel.Id) -> AssetHubStakingRoute? {
        routes.first { $0.stakingChainId == chainId }
    }

    static func migrating(_ chainId: ChainModel.Id) -> AssetHubStakingRoute? {
        routes.first { $0.relayChainId == chainId }
    }

    /// The asset a saved staking choice means in this build: a relay's native token moves to its Asset Hub, where the
    /// stake now lives. A saved non-native asset is never turned into the staking token. Nil when the asset is not
    /// offered for staking.
    static func selectedAsset(_ identifier: ChainAssetId, in chains: [ChainModel]) -> ChainAsset? {
        let route = migrating(identifier.chainId)

        if let route = route, route.nativeAssetId != identifier.assetId {
            return nil
        }

        let chainId = route?.stakingChainId ?? identifier.chainId

        guard
            let chain = chains.first(where: { $0.chainId == chainId && !$0.disabled }),
            let asset = chain.assets.first(where: { $0.id == identifier.assetId && $0.staking != nil })
        else {
            return nil
        }

        return ChainAsset(chain: chain, asset: asset)
    }

    /// On an Asset Hub only the relay's native token stakes, as direct (relay chain) staking. A downloaded list that
    /// declares staking for any other asset there is not followed.
    static func offersStaking(_ asset: AssetModel, on chain: ChainModel) -> Bool {
        guard let route = staking(on: chain.chainId) else {
            return asset.staking != nil
        }

        return chain.parentId == route.relayChainId &&
            asset.id == route.nativeAssetId &&
            asset.isUtility &&
            asset.type == .normal &&
            asset.staking == .relayChain
    }

    /// Portable metadata describes these runtimes, so a missing chain types entry is not a missing schema.
    static func runtimeTypes(for chainId: ChainModel.Id, existing: Data?) -> Data? {
        if let existing = existing {
            return existing
        }

        guard staking(on: chainId) != nil else {
            return nil
        }

        return Data("{\"runtime_id\":0,\"versioning\":[],\"types\":{}}".utf8)
    }
}
