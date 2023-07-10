import Foundation
@testable import fearless

enum ChainModelGenerator {
    static func generate(
        count: Int,
        withTypes: Bool = true,
        staking: RawStakingType? = nil,
        hasCrowdloans: Bool = false
    ) -> [ChainModel] {
        (0..<count).map { index in
            let chainId = Data.random(of: 32)!.toHex()

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

            let externalApi: ChainModel.ExternalApiSet? = generateExternaApis(
                for: chainId,
                staking: staking,
                hasCrowdloans: hasCrowdloans
            )

            let chain = ChainModel(
                            chainId: chainId,
                            parentId: nil,
                            name: String(chainId.reversed()),
                            assets: [],
                            nodes: [node],
                            addressPrefix: UInt16(index),
                            types: types,
                            icon: URL(string: "https://github.com")!,
                            options: options.isEmpty ? nil : options,
                            externalApi: externalApi,
                            customNodes: nil,
                            iosMinAppVersion: nil
                        )
            let asset = generateAssetWithId("", symbol: "", assetPresicion: 12, chainId: chainId)
            let chainAsset = generateChainAsset(asset, chain: chain, staking: staking)
            let chainAssets = Set(arrayLiteral: chainAsset)
            chain.assets = chainAssets
            return chain
        }
    }

    static func generateChain(
        generatingAssets count: Int,
        addressPrefix: UInt16,
        assetPresicion: UInt16 = (9...18).randomElement()!,
        staking: RawStakingType? = nil,
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

        let chain = ChainModel(
            chainId: chainId,
            parentId: nil,
            name: UUID().uuidString,
            assets: [],
            nodes: [node],
            addressPrefix: addressPrefix,
            types: nil,
            icon: Constants.dummyURL,
            options: options.isEmpty ? nil : options,
            externalApi: externalApi,
            customNodes: nil,
            iosMinAppVersion: nil
        )
        let chainAssetsArray: [ChainAssetModel] = (0..<count).map { index in
            let asset = generateAssetWithId(
                AssetModel.Id(index),
                symbol: "\(index)",
                assetPresicion: assetPresicion
            )
            return generateChainAsset(asset, chain: chain, staking: staking)
        }
        let chainAssets = Set(chainAssetsArray)
        chain.assets = chainAssets
        return chain
    }
    
    static func generateChainAsset(_ asset: AssetModel, chain: ChainModel, staking: RawStakingType? = nil, chainAssetType: ChainAssetType = .normal) -> ChainAssetModel {
        ChainAssetModel(
            assetId: asset.id,
            type: chainAssetType,
            asset: asset,
            chain: chain,
            isUtility: asset.chainId == chain.chainId,
            isNative: true)
    }

    static func generateAssetWithId(
        _ identifier: AssetModel.Id,
        symbol: String,
        assetPresicion: UInt16 = (9...18).randomElement()!,
        chainId: String = ""
    ) -> AssetModel {
        AssetModel(
            id: identifier,
            symbol: symbol,
            chainId: chainId,
            precision: assetPresicion,
            icon: nil,
            priceId: nil,
            price: nil,
            fiatDayChange: nil,
            transfersEnabled: true,
            currencyId: nil,
            displayName: nil,
            existentialDeposit: nil,
            color: nil
        )
    }

    private static func generateExternaApis(
        for chainId: ChainModel.Id,
        staking: RawStakingType?,
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
            return ChainModel.ExternalApiSet(staking: stakingApi, history: nil, crowdloans: crowdloanApi, explorers: nil)
        } else {
            return nil
        }
    }
}
