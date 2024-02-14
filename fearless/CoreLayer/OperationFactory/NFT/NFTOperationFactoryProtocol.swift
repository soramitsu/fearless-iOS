import Foundation
import RobinHood
import SSFModels

protocol NFTOperationFactoryProtocol {
    func fetchNFTs(
        chain: SSFModels.ChainModel,
        address: String,
        excludeFilters: [NftCollectionFilter]
    ) -> RobinHood.CompoundOperationWrapper<[NFT]?>

    func fetchCollections(
        chain: ChainModel,
        address: String,
        excludeFilters: [NftCollectionFilter]
    ) -> CompoundOperationWrapper<[NFTCollection]?>
}
