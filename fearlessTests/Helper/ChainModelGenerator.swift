import Foundation
@testable import fearless

enum ChainModelGenerator {
    static func generate(
        count: Int,
        withTypes: Bool = true,
        hasStaking: Bool = false,
        hasCrowdloans: Bool = false
    ) -> [ChainModel] {
        (0..<count).map { index in
            let chainId = Data.random(of: 32)!.toHex()

            let asset = AssetModel(
                assetId: UInt32(index),
                icon: nil,
                name: chainId,
                symbol: chainId.prefix(3).uppercased(),
                precision: 12,
                priceId: nil,
                staking: hasStaking ? "relaychain" : nil
            )

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
                hasStaking: hasStaking,
                hasCrowdloans: hasCrowdloans
            )

            return ChainModel(
                chainId: chainId,
                parentId: nil,
                name: String(chainId.reversed()),
                assets: [asset],
                nodes: [node],
                addressPrefix: UInt16(index),
                types: types,
                icon: URL(string: "https://github.com")!,
                options: options.isEmpty ? nil : options,
                externalApi: externalApi
            )
        }
    }

    static func generateChain(
        generatingAssets count: Int,
        addressPrefix: UInt16,
        assetPresicion: UInt16 = (9...18).randomElement()!,
        hasStaking: Bool = false,
        hasCrowdloans: Bool = false
    ) -> ChainModel {
        let chainId = Data.random(of: 32)!.toHex()

        let assets = (0..<count).map { index in
            generateAssetWithId(
                AssetModel.Id(index),
                assetPresicion: assetPresicion,
                hasStaking: hasStaking
            )
        }

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
            hasStaking: hasStaking,
            hasCrowdloans: hasCrowdloans
        )

        return ChainModel(
            chainId: chainId,
            parentId: nil,
            name: UUID().uuidString,
            assets: Set(assets),
            nodes: [node],
            addressPrefix: addressPrefix,
            types: nil,
            icon: Constants.dummyURL,
            options: options.isEmpty ? nil : options,
            externalApi: externalApi
        )
    }

    static func generateAssetWithId(
        _ identifier: AssetModel.Id,
        assetPresicion: UInt16 = (9...18).randomElement()!,
        hasStaking: Bool = false
    ) -> AssetModel {
        AssetModel(
            assetId: identifier,
            icon: Constants.dummyURL,
            name: UUID().uuidString,
            symbol: String(UUID().uuidString.prefix(3)),
            precision: assetPresicion,
            priceId: nil,
            staking: hasStaking ? "relaychain" : nil
        )
    }

    private static func generateExternaApis(
        for chainId: ChainModel.Id,
        hasStaking: Bool,
        hasCrowdloans: Bool
    ) -> ChainModel.ExternalApiSet? {
        let crowdloanApi: ChainModel.ExternalApi?

        if hasCrowdloans {
            crowdloanApi = ChainModel.ExternalApi(
                type: "test",
                url: URL(string: "https://crowdloan.io/\(chainId)-\(UUID().uuidString).json")!
            )
        } else {
            crowdloanApi = nil
        }

        let stakingApi: ChainModel.ExternalApi?

        if hasStaking {
            stakingApi = ChainModel.ExternalApi(
                type: "test",
                url: URL(string: "https://staking.io/\(chainId)-\(UUID().uuidString).json")!
            )
        } else {
            stakingApi = nil
        }

        if crowdloanApi != nil || stakingApi != nil {
            return ChainModel.ExternalApiSet(staking: stakingApi, history: nil, crowdloans: crowdloanApi)
        } else {
            return nil
        }
    }
}
