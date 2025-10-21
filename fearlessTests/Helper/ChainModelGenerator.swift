import Foundation
import SSFModels
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
                rank: nil,
                disabled: false,
                chainId: chainId,
                parentId: nil,
                paraId: nil,
                name: String(chainId.reversed()),
                xcm: nil,
                nodes: [node],
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

            let asset = generateAssetWithId("asset_\(index)", symbol: "TST\(index)", assetPresicion: 12, chainId: chainId)
            // Set tokens on the chain to reflect generated assets
            chain.tokens = ChainRemoteTokens(type: .config, whitelist: nil, utilityId: nil, tokens: Set([asset]))
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
            nodes: [node],
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
        let chainAssetsArray: [ChainAsset] = (0..<count).map { index in
            let asset = generateAssetWithId(
                AssetModel.Id(index),
                symbol: "\(index)",
                assetPresicion: assetPresicion
            )
            return generateChainAsset(asset, chain: chain, staking: staking)
        }
        let assets = Set(chainAssetsArray.map { $0.asset })
        chain.tokens = ChainRemoteTokens(type: .config, whitelist: nil, utilityId: nil, tokens: assets)
        return chain
    }
    
    static func generateChainAsset(_ asset: AssetModel, chain: ChainModel, staking: RawStakingType? = nil) -> ChainAsset {
        // SSFModels uses ChainAsset(chain:asset:)
        ChainAsset(chain: chain, asset: asset)
    }

    static func generateAssetWithId(
        _ identifier: AssetModel.Id,
        symbol: String,
        assetPresicion: UInt16 = (9...18).randomElement()!,
        chainId: String = ""
    ) -> AssetModel {
        // Map to current SSFModels initializer; keep values simple for tests
        let tokenProps = TokenProperties(priceId: nil, currencyId: nil, color: nil, type: nil, isNative: false, stacking: nil)
        return AssetModel(
            id: identifier,
            name: symbol.isEmpty ? "Test Asset" : symbol,
            symbol: symbol,
            isUtility: true,
            precision: assetPresicion,
            icon: nil,
            substrateType: nil,
            ethereumType: nil,
            tokenProperties: tokenProps,
            price: nil,
            priceId: nil,
            coingeckoPriceId: nil,
            priceProvider: nil
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
