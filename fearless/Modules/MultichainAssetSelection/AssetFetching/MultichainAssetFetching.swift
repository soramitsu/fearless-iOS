import Foundation
import SSFModels

protocol MultichainAssetFetching {
    func fetchAssets(for chain: ChainModel) async throws -> [ChainAsset]
}
