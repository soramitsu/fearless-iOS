import Foundation
@testable import fearless
import SSFModels

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
                rank: nil,
                disabled: false,
                chainId: chainId,
                parentId: nil,
                paraId: nil,
                name: String(chainId.reversed()),
                xcm: nil,
                nodes: Set([node]),
                addressPrefix: UInt16(index),
                types: types,
                icon: URL(string: "https://github.com")!,
                options: options.isEmpty ? nil : options,
                externalApi: externalApi,
                selectedNode: nil,
                customNodes: nil,
                iosMinAppVersion: nil,
                identityChain: nil
            )
            _ = generateChainAsset(
                generateAssetWithId("asset-\(index)", symbol: "AST\(index)", assetPresicion: 12),
                chain: chain,
                staking: staking
            )
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
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: UUID().uuidString,
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: addressPrefix,
            types: nil,
            icon: Constants.dummyURL,
            options: options.isEmpty ? nil : options,
            externalApi: externalApi,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        _ = (0..<count).map { index in
            let asset = generateAssetWithId("asset-\(index)", symbol: "A\(index)", assetPresicion: assetPresicion)
            return generateChainAsset(asset, chain: chain, staking: staking)
        }
        return chain
    }
    
    static func generateChainAsset(_ asset: AssetModel, chain: ChainModel, staking: RawStakingType? = nil) -> ChainAsset {
        ChainAsset(chain: chain, asset: asset)
    }

    static func generateAssetWithId(
        _ identifier: String,
        symbol: String,
        assetPresicion: UInt16 = (9...18).randomElement()!
    ) -> AssetModel {
        AssetModel(
            id: identifier,
            name: symbol.uppercased(),
            symbol: symbol,
            precision: assetPresicion,
            icon: nil,
            currencyId: nil,
            existentialDeposit: nil,
            color: nil,
            isUtility: false,
            isNative: false,
            staking: nil,
            purchaseProviders: nil,
            type: nil,
            ethereumType: nil,
            priceProvider: nil,
            coingeckoPriceId: nil
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
            return ChainModel.ExternalApiSet(
                staking: stakingApi,
                history: nil,
                crowdloans: crowdloanApi,
                explorers: nil,
                pricing: nil
            )
        } else {
            return nil
        }
    }
}
