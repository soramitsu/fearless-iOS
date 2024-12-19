import Foundation
import SSFModels

protocol MultichainAssetFetching {
    func fetchAssets(for chain: ChainModel, preferredDataSourceType: PreferredDataSourceType) async throws -> [ChainAsset]
}
