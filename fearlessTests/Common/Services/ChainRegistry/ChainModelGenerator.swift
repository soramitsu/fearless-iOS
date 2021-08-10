import Foundation
@testable import fearless

final class ChainModelGenerator {
    static func generate(count: Int) -> [ChainModel] {
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
                url: URL(string: "wss://node.io")!,
                name: chainId
            )

            return ChainModel(
                chainId: chainId,
                assets: [asset],
                nodes: [node],
                addressPrefix: UInt16(index),
                types: URL(string: "https://github.com")!,
                icon: URL(string: "https://github.com")!,
                isEthereumBased: false
            )
        }
    }
}
