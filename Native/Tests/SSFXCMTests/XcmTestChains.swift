import SSFModels

/// Chain models shaped like the remote config's, for the call factory tests.
enum XcmTestChains {
    static let polkadotId = Chain.polkadot.genesisHash
    static let kusamaId = Chain.kusama.genesisHash

    static let polkadot = chain(id: polkadotId, name: "Polkadot", assets: [utility("DOT")])
    static let assetHub = chain(
        id: "68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f",
        parentId: polkadotId,
        paraId: "1000",
        name: "Polkadot Asset Hub",
        assets: [utility("DOT"), asset("USDt")],
        xcm: xcm(assets: [("usdt-ah", "USDt"), ("dot-ah", "DOT")])
    )
    static let bridgeHub = chain(
        id: "dcf691b5a3fbe24adc99ddc959c0561b973e329b1aef4c4b22e7bb2ddecb4464",
        parentId: polkadotId,
        paraId: "1002",
        name: "Polkadot BridgeHub",
        assets: [utility("DOT")]
    )
    static let acala = chain(
        id: Chain.acala.genesisHash,
        parentId: polkadotId,
        paraId: "2000",
        name: "Acala",
        assets: [utility("ACA")],
        xcm: xcm(assets: [("usdt", "USDt"), ("dot", "DOT"), ("astr", "ASTR"), ("lcdot", "lcDOT")])
    )
    static let astar = chain(
        id: "9eb76c5184c4ab8679d2d5d819fdf90b9c001403e9e17da2e14b6d8aec4029c6",
        parentId: polkadotId,
        paraId: "2006",
        name: "Astar",
        assets: [utility("ASTR")]
    )
    static let kusama = chain(id: kusamaId, name: "Kusama", assets: [utility("KSM")])
    static let kusamaAssetHub = chain(
        id: "48239ef607d7928874027a43a67689209727dfb3d3dc5e5b03a39bdc2eda771a",
        parentId: kusamaId,
        paraId: "1000",
        name: "Kusama Asset Hub",
        assets: [utility("KSM")]
    )
    static let liberland = chain(id: Chain.liberland.genesisHash, name: "Liberland")
    static let soraMainnet = chain(id: Chain.soraMain.genesisHash, name: "SORA Mainnet")
    static let westend = chain(
        id: Chain.westend.genesisHash,
        name: "Westend",
        assets: [utility("WND")]
    )
    static let ethereum = chain(id: "1", name: "Ethereum", options: [.ethereum])
    static let bnbChain = chain(id: "0x38", name: "BNB Smart Chain", options: [.ethereum])

    static func chain(
        id: String,
        parentId: String? = nil,
        paraId: String? = nil,
        name: String,
        assets: Set<AssetModel> = [],
        xcm: XcmChain? = nil,
        options: [ChainOptions]? = nil
    ) -> ChainModel {
        ChainModel(
            rank: 0,
            disabled: false,
            chainId: id,
            parentId: parentId,
            paraId: paraId,
            name: name,
            assets: assets,
            xcm: xcm,
            nodes: [],
            addressPrefix: 0,
            icon: nil,
            options: options,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    static func xcm(
        assets: [(id: String, symbol: String)],
        destWeightIsPrimitive: Bool = false
    ) -> XcmChain {
        XcmChain(
            xcmVersion: .V3,
            destWeightIsPrimitive: destWeightIsPrimitive,
            availableAssets: assets.map { .init(id: $0.id, symbol: $0.symbol) },
            availableDestinations: []
        )
    }

    private static func utility(_ symbol: String) -> AssetModel {
        AssetModel(
            id: symbol.lowercased(),
            name: symbol,
            symbol: symbol,
            precision: 10,
            isUtility: true,
            isNative: true
        )
    }

    private static func asset(_ symbol: String) -> AssetModel {
        AssetModel(
            id: symbol.lowercased(),
            name: symbol,
            symbol: symbol,
            precision: 6,
            isUtility: false,
            isNative: false
        )
    }
}
