import Foundation
import SSFModels

public enum ChainModelGenerator {
    public static func generate(
        name: String? = nil,
        chainId: String? = nil,
        parentId: String? = nil,
        paraId: String? = nil,
        count: Int,
        withTypes: Bool = true,
        staking: StakingType? = nil,
        hasCrowdloans: Bool = false,
        isEthereumBased: Bool = false
    ) -> [ChainModel] {
        (0 ..< count).map { index in
            let chainId = chainId ?? Data.random(of: 32)!.toHex()

            let node = ChainNodeModel(
                url: URL(string: "wss://node.io/\(chainId)")!,
                name: chainId,
                apikey: nil
            )

            let types = withTypes ? ChainModel.TypesSettings(
                url: URL(string: "https://github.com")!,
                overridesCommon: false
            ) : nil

            var options: [ChainOptions] = []

            if hasCrowdloans {
                options.append(.crowdloans)
            }
            if isEthereumBased {
                options.append(.ethereumBased)
            }

            let externalApi: ChainModel.ExternalApiSet? = generateExternaApis(
                for: chainId,
                staking: staking,
                hasCrowdloans: hasCrowdloans
            )

            let availableDestinations = XcmAvailableDestination(
                chainId: Data.random(of: 32)!.toHex(),
                bridgeParachainId: nil,
                assets: []
            )

            let xcm = XcmChain(
                xcmVersion: .V3,
                destWeightIsPrimitive: nil,
                availableAssets: [],
                availableDestinations: [availableDestinations]
            )

            let chain = ChainModel(
                rank: nil,
                disabled: false,
                chainId: chainId,
                parentId: parentId,
                paraId: paraId,
                name: name ?? String(chainId.reversed()),
                assets: [],
                xcm: xcm,
                nodes: [node],
                addressPrefix: UInt16(index),
                types: types,
                icon: URL(string: "https://github.com")!,
                options: options.isEmpty ? nil : options,
                externalApi: externalApi,
                customNodes: nil,
                iosMinAppVersion: nil,
                identityChain: nil
            )

            let asset = generateAssetWithId("", symbol: "", assetPresicion: 12, chainId: chainId)
            let chainAssets = Set(arrayLiteral: asset)
            chain.assets = chainAssets
            return chain
        }
    }

    public static func withAvailableXcmAssets(
        for chain: ChainModel,
        availableAssets: [XcmAvailableAsset]
    ) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: chain.disabled,
            chainId: chain.chainId,
            parentId: chain.parentId,
            paraId: chain.paraId,
            name: chain.name,
            assets: chain.assets,
            xcm: XcmChain(
                xcmVersion: chain.xcm?.xcmVersion,
                destWeightIsPrimitive: chain.xcm?.destWeightIsPrimitive,
                availableAssets: availableAssets,
                availableDestinations: chain.xcm?.availableDestinations ?? []
            ),
            nodes: chain.nodes,
            addressPrefix: chain.addressPrefix,
            types: chain.types,
            icon: chain.icon,
            options: chain.options,
            externalApi: chain.externalApi,
            selectedNode: chain.selectedNode,
            customNodes: chain.customNodes,
            iosMinAppVersion: chain.iosMinAppVersion,
            identityChain: nil
        )
    }

    public static func generateChain(
        generatingAssets count: Int,
        addressPrefix: UInt16,
        assetPresicion: UInt16 = (9 ... 18).randomElement()!,
        staking: StakingType? = nil,
        hasCrowdloans: Bool = false
    ) -> ChainModel {
        let chainId = Data.random(of: 32)!.toHex()

        let urlString = "node\(Data.random(of: 32)!.toHex()).io"

        let node = ChainNodeModel(
            url: URL(string: urlString)!,
            name: UUID().uuidString,
            apikey: nil
        )

        var options: [ChainOptions] = []

        if hasCrowdloans {
            options.append(.crowdloans)
        }

        let externalApi: ChainModel.ExternalApiSet? = generateExternaApis(
            for: chainId,
            staking: staking,
            hasCrowdloans: hasCrowdloans
        )

        let availableDestinations = XcmAvailableDestination(
            chainId: Data.random(of: 32)!.toHex(),
            bridgeParachainId: nil,
            assets: []
        )

        let xcm = XcmChain(
            xcmVersion: .V3,
            destWeightIsPrimitive: nil,
            availableAssets: [],
            availableDestinations: [availableDestinations]
        )

        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: UUID().uuidString,
            assets: [],
            xcm: xcm,
            nodes: [node],
            addressPrefix: addressPrefix,
            types: nil,
            icon: URL(string: "google.com")!,
            options: options.isEmpty ? nil : options,
            externalApi: externalApi,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        let chainAssetsArray: [AssetModel] = (0 ..< count).map { index in
            generateAssetWithId(
                AssetModel.Id(index),
                symbol: "\(index)",
                assetPresicion: assetPresicion
            )
        }
        let chainAssets = Set(chainAssetsArray)
        chain.assets = chainAssets
        return chain
    }

    public static func generateAssetWithId(
        _ identifier: AssetModel.Id,
        symbol: String,
        assetPresicion: UInt16 = (9 ... 18).randomElement()!,
        chainId _: String = "",
        substrateAssetType: SubstrateAssetType = .normal,
        currencyId: String? = nil
    ) -> AssetModel {
        AssetModel(
            id: identifier,
            name: "",
            symbol: symbol,
            precision: assetPresicion,
            icon: nil,
            price: nil,
            fiatDayChange: nil,
            currencyId: currencyId,
            existentialDeposit: nil,
            color: nil,
            isUtility: false,
            isNative: false,
            staking: nil,
            purchaseProviders: nil,
            type: substrateAssetType,
            ethereumType: .normal,
            priceProvider: nil,
            coingeckoPriceId: nil
        )
    }

    private static func generateExternaApis(
        for chainId: ChainModel.Id,
        staking: StakingType?,
        hasCrowdloans: Bool
    ) -> ChainModel.ExternalApiSet? {
        let crowdloanApi: ChainModel.ExternalResource?

        if hasCrowdloans {
            crowdloanApi = ChainModel.ExternalResource(
                type: "test",
                url: URL(string: "https://crowdloan.io/\(chainId)-\(UUID().uuidString).json")!
            )
        } else {
            crowdloanApi = nil
        }

        let stakingApi: ChainModel.BlockExplorer?

        if staking != nil {
            stakingApi = ChainModel.BlockExplorer(
                type: "test",
                url: URL(string: "https://staking.io/\(chainId)-\(UUID().uuidString).json")!
            )
        } else {
            stakingApi = nil
        }

        if crowdloanApi != nil || stakingApi != nil {
            return ChainModel.ExternalApiSet(
                staking: stakingApi,
                history: nil,
                crowdloans: crowdloanApi,
                explorers: nil
            )
        } else {
            return nil
        }
    }
}
