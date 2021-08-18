import Foundation
@testable import fearless

final class ChainModelGenerator {
    static func generate(count: Int, withTypes: Bool = true) -> [ChainModel] {
        (0..<count).map { index in
            let chainId = Data.random(of: 32)!.toHex()

            let asset = AssetModel(
                assetId: UInt32(index),
                chainId: chainId,
                icon: nil,
                name: chainId,
                symbol: chainId.prefix(3).uppercased(),
                precision: 12
            )

            let node = ChainNodeModel(
                chainId: chainId,
                url: URL(string: "wss://node.io/\(chainId)")!,
                name: chainId
            )

            let types = withTypes ? ChainModel.TypesSettings(
                url: URL(string: "https://github.com")!,
                overridesCommon: false
            ) : nil

            return ChainModel(
                chainId: chainId,
                parentId: nil,
                assets: [asset],
                nodes: [node],
                addressPrefix: UInt16(index),
                types: types,
                icon: URL(string: "https://github.com")!,
                options: []
            )
        }
    }
}
