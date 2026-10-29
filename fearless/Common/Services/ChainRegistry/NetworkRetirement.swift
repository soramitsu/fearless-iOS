import Foundation
import SSFModels

/// Networks and relay-chain features this build no longer offers, whatever a downloaded chain list says.
///
/// The chain list is read from `master` at run time, so a served list can lag behind this build. Every
/// entry was checked on 29 October 2026 against the relay chain (`Paras::ParaLifecycles` and
/// `Paras::MostRecentContext`) and against every node the lists name and the public endpoints its project
/// publishes: none produces blocks any more. A chain that left its relay but runs on its own, such as AvN,
/// is not retired.
enum NetworkRetirement {
    /// Left out of every synced list. `ChainSyncService` keeps a stored copy disabled, so wallets keep their
    /// accounts, but the app never connects to, lists or signs for these networks.
    static let retiredChainIds: Set<ChainModel.Id> = [
        // No longer registered on the relay chain. Moonbeam left Polkadot for Base on 31 July 2026.
        "fe58ea77779b7abda7da4ec526d14db9b1e9cd40a217c34892af80a9b332b76d", // Moonbeam (Polkadot 2004)
        "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b", // Moonriver (Kusama 2023)
        "4a12be580bb959937a1c7a61d5cf24428ed67fa571974b4007645d1886e7c89f", // Subsocial (Polkadot 2101)
        "724c168d8e86b78b831c641e2cc822b8d1bf99fa0b4b28fe59985cd6fd580215", // Integritee (Polkadot 2039)
        "cdedc8eadbfa209d3f207bba541e57c3c58a667b05a2e1d1e86353c9000758da", // Integritee (Kusama 2015)
        "31a7d8914fb31c249b972f18c115f1e22b4b039abbcb03c73b6774c5642f9efe", // InvArch (Polkadot 3340)
        // No block included by the relay chain for at least 30 days.
        "c14597baeccb232d662770d2d50ae832ca8c3192693d2b0814e6433f2888ddd6", // Bitgreen (Polkadot 2048)
        "f22b7850cdd5a7657bbfd90ac86441275bbc57ace3d2698a740c7b0ec4de5ec3", // Pioneer (Kusama 2096)
        "35a06bfec2edf0ff4be89a6428ccd9ff5bd0167d618c5a0d4341f9600a458d14", // Bajun (Kusama 2119)
        "64a1c658a48b2e70a7fb1ad4c39eea35022568c20fc44a6e2e3d0a57aee6053b", // Parallel Heiko (Kusama 2085)
        "4ac80c99289841dd946ef92765bf659a307d39189b3ce374a92b5f0415ee17a1", // Calamari (Kusama 2084)
        "0f62b701fb12d02237a33b84818c11f621653d2b1614c777973babf4652b535d", // Turing (Kusama 2114)
        "7eb9354488318e7549c722669dcbdcdc526f1fef1420e7944667212f3601fdbd", // Polimec (Polkadot 3344)
        "6811a339673c9daa897944dcdac99c6e2939cc88245ed21951a0a3c9a2be75bc", // Picasso (Kusama 2087)
        "5c7bd13edf349b33eb175ffae85210299e324d852916336027391536e686f267", // Clover (Polkadot 2002)
        "6d8d9f145c2177fa83512492cdd80a71e29f22473f4a8943a6292149ac319fb9", // SORA Kusama parachain (2011)
        "1bb969d85965e4bb5a651abbedf21a54b6b31a21f66b5401cc3f1e286268d736", // Phala (Polkadot 2035)
        "e92d165ad41e41e215d09713788173aecfdbe34d3bed29409d33a2ef03980738", // SORA Polkadot parachain (2025)
        "97da7ede98d7bad4e36b4d734b6055425a3be036da2a332ea5a7037656427a21", // Nodle (Polkadot 2026)
        "cd4d732201ebe5d6b014edda071c4203e16867305332301dc8d092044b28e554", // Quartz (Kusama 2095)
        "411f057b9107718c9624d6aa4a3f23c1653898297f3d4d529d9bb6511a39dd21", // KILT Spiritnet (Polkadot 2086)
        "aa3876c1dc8a1afcc2e9a685a49ff7704cfd36ad8c90bf2702b9d1b00cc40011", // Altair (Kusama 2088)
        "cceae7f3b9947cdb67369c026ef78efa5f34a08fe5808d373c04421ecf4f1aaf", // Amplitude (Kusama 2124)
        "4319cc49ee79495b57a1fec4d2bd43f59052dcc690276de566c2691d6df4f7b8", // Crust (Polkadot 2008)
        "1bf2a2ecb4a868de66ea8610f2ce7c8c43706561b6476031315f6640fe38e060", // Zeitgeist (Polkadot 2092)
        "d4c0c08ca49dc7c680c3dac71a7c0703e5b222f4b6c03fe4c5219bb8f22c18dc", // Crust Shadow (Kusama 2012)
        "bf88efe70e9e0e916416e8bed61f2b45717f517d7f3523e33c7b001e5ffcbc72", // Interlay (Polkadot 2032)
        "9af9a64e6e4da8e3073901c3ff0cc4c3aad9563786d89daf6ad820b6e14a0b8b", // Kintsugi (Kusama 2092)
        "b3db41421702df9a7fcac62b53ffeac85f7853cc4e689e0b93aeb3db18c09d82", // Centrifuge (Polkadot 2031)
        "daab8df776eb52ec604a5df5d388bb62a050a0aaec4556a64265b9d42755552d", // Composable (Polkadot 2019)
        "f3c7ad88f6a80f366c4be216691411ef0622e8b809b1046ea297ef106058d4eb", // Manta (Polkadot 2104)
        "631ccc82a078481584041656af292834e1ae6daab61d2875b4dd0c14bb9b17bc", // Robonomics (Kusama 2048)
        // Block production stopped: the Polygon zkEVM sequencer shut down on 1 July 2026.
        "1101", // Polygon zkEVM
        // No node answers anywhere, in probes 12 hours apart.
        "3920bcb4960a1eef5580cd5367ff3f430eef052774f78468852f7b9cb39f8a3c", // Polkadex
        "72888", // CAGA
        "72778", // CAGA Ankara Testnet
        "995", // 5ire
        "168168", // ZChains
        "2525" // inEVM
    ]

    /// Relay chains whose staking, nomination pools and crowdloan funds moved to their Asset Hub (Westend first,
    /// Kusama on 7 October 2025, Polkadot on 4 November 2025). Their relay runtimes have no `Staking` storage
    /// left, so staking, pool staking and crowdloans are not offered on them.
    static let assetHubMigratedRelayChainIds: Set<ChainModel.Id> = [
        Chain.polkadot.genesisHash,
        Chain.kusama.genesisHash,
        Chain.westend.genesisHash
    ]

    static func applying(to chains: [ChainModel]) -> [ChainModel] {
        chains.compactMap { chain in
            guard !retiredChainIds.contains(chain.chainId) else {
                return nil
            }

            guard assetHubMigratedRelayChainIds.contains(chain.chainId) else {
                return chain
            }

            return chain.removingRelayStaking()
        }
    }
}

private extension ChainModel {
    func removingRelayStaking() -> ChainModel {
        ChainModel(
            rank: rank,
            disabled: disabled,
            chainId: chainId,
            parentId: parentId,
            paraId: paraId,
            name: name,
            assets: Set(assets.map { $0.removingStaking() }),
            xcm: xcm,
            nodes: nodes,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options?.filter { $0 != .poolStaking && $0 != .crowdloans },
            externalApi: externalApi,
            selectedNode: selectedNode,
            customNodes: customNodes,
            iosMinAppVersion: iosMinAppVersion,
            identityChain: identityChain
        )
    }
}

private extension AssetModel {
    func removingStaking() -> AssetModel {
        AssetModel(
            id: id,
            name: name,
            symbol: symbol,
            precision: precision,
            icon: icon,
            price: price,
            fiatDayChange: fiatDayChange,
            currencyId: currencyId,
            existentialDeposit: existentialDeposit,
            color: color,
            isUtility: isUtility,
            isNative: isNative,
            staking: nil,
            purchaseProviders: purchaseProviders,
            type: type,
            ethereumType: ethereumType,
            priceProvider: priceProvider,
            coingeckoPriceId: coingeckoPriceId
        )
    }
}

extension Array where Element == ChainModel {
    /// The chains a wallet screen lists: every enabled one, plus a disabled one where the wallet keeps its own
    /// account, so a key imported for a network that has since been retired can still be viewed and exported.
    func listedForKeyAccess(by wallet: MetaAccountModel) -> [ChainModel] {
        let ownAccountChainIds = Set(wallet.chainAccounts.map(\.chainId))
        return filter { !$0.disabled || ownAccountChainIds.contains($0.chainId) }
    }
}
