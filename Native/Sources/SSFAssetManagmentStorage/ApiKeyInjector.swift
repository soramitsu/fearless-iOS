import Foundation
import SSFModels

public protocol ApiKeyInjector {
    func getBlockExplorerKey(
        for type: BlockExplorerType,
        chainId: ChainModel.Id
    ) -> String?
    func getNodeApiKey(
        for chainId: String,
        apiKeyName: String
    ) -> String?
}
