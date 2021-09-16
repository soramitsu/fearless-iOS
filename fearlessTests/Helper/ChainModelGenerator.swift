import Foundation
@testable import fearless

enum ChainModelGenerator {
    static func generate(count: Int, withTypes: Bool = true) -> [ChainModel] {
        (0..<count).map { index in
            let chainId = Data.random(of: 32)!.toHex()

            let asset = AssetModel(
                assetId: UInt32(index),
                icon: nil,
                name: chainId,
                symbol: chainId.prefix(3).uppercased(),
                precision: 12,
                staking: "relaychain"
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

            return ChainModel(
                chainId: chainId,
                parentId: nil,
                name: String(chainId.reversed()),
                assets: [asset],
                nodes: [node],
                addressPrefix: UInt16(index),
                types: types,
                icon: URL(string: "https://github.com")!,
                options: []
            )
        }
    }

    static func generateChain(generatingAssets count: Int, addressPrefix: UInt16) -> ChainModel {
        let assets = (0..<count).map { index in
            generateAssetWithId(AssetModel.Id(index))
        }

        let urlString = "node\(Data.random(of: 32)!.toHex()).io"

        let node = ChainNodeModel(
            url: URL(string: urlString)!,
            name: UUID().uuidString,
            apikey: nil
        )

        return ChainModel(
            chainId: Data.random(of: 32)!.toHex(),
            parentId: nil,
            name: UUID().uuidString,
            assets: Set(assets),
            nodes: [node],
            addressPrefix: addressPrefix,
            types: nil,
            icon: Constants.dummyURL,
            options: []
        )
    }

    static func generateAssetWithId(_ identifier: AssetModel.Id) -> AssetModel {
        AssetModel(
            assetId: identifier,
            icon: Constants.dummyURL,
            name: UUID().uuidString,
            symbol: String(UUID().uuidString.prefix(3)),
            precision: (9...18).randomElement()!,
            staking: nil
        )
    }
}
