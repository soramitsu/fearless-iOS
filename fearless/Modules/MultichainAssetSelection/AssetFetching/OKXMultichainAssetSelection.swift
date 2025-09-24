import Foundation
import SSFModels

class OKXMultichainAssetFetching: MultichainAssetFetching {
    func fetchAssets(for _: ChainModel) async throws -> [ChainAsset] {
        []
    }
}
