import Foundation
@testable import fearless

final class ChainModelGenerator {
    static func generate(count: Int) -> [ChainModel] {
        (0..<count).map { index in
            let chainId = Data.random(of: 32)!.toHex()

            let asset = AssetModel(
                assetId: UInt32(index),
                chainId: chainId,
                name: chainId,
                symbol: chainId.prefix(3).uppercased(),
                precision: 12,
                isUtility: true
            )

            let node = ChainNodeModel(
                chainId: chainId,
                url: URL(string: "wss://node.io")!,
                name: chainId,
                rank: Int32(index)
            )

            return ChainModel(
                chainId: chainId,
                assets: [asset],
                nodes: [node],
                prefix: UInt16(index),
                typesURL: URL(string: "https://github.com")!,
                preferredUrl: nil,
                isEthereum: false
            )
        }
    }
}
