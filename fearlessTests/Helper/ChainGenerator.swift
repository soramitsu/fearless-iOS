import Foundation
@testable import fearless

enum ChainGenerator {
    static func generateChain(generatingAssets count: Int, addressPrefix: UInt16) -> ChainModel {
        let assets = (0..<count).map { index in
            generateAssetWithId(AssetModel.Id(index))
        }

        let urlString = "node\(Data.random(of: 32)!.toHex()).io"

        let node = ChainNodeModel(
            url: URL(string: urlString)!,
            name: UUID().uuidString
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
            precision: (9...18).randomElement()!
        )
    }
}
