import Foundation
import RobinHood
import SSFModels

protocol NFTOperationFactoryProtocol {
    func fetchNFTs(
        chain: ChainModel,
        address: String
    ) -> CompoundOperationWrapper<[NFT]?>
    func fetchCollections(
        chain: ChainModel,
        address: String
    ) -> CompoundOperationWrapper<[NFTCollection]?>
}
