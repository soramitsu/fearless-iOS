import Foundation
@testable import fearless
import SSFModels
import SSFRuntimeCodingService
import FearlessUtils
import RobinHood

// Disambiguate model types between fearless and SSFModels in tests
typealias MetaAccountModel = fearless.MetaAccountModel
typealias ChainAccountResponse = fearless.ChainAccountResponse
typealias ChainAccountInfo = fearless.ChainAccountInfo
typealias ChainModel = SSFModels.ChainModel
typealias ChainNodeModel = SSFModels.ChainNodeModel
typealias ChainAsset = SSFModels.ChainAsset
typealias AssetModel = SSFModels.AssetModel
typealias CryptoType = FearlessUtils.CryptoType
typealias RuntimeProviderProtocol = SSFRuntimeCodingService.RuntimeProviderProtocol

// Keep generated legacy mocks compiling while production protocol shims are removed.
extension AccountRepositoryFactoryProtocol {
    @available(*, deprecated, message: "Use createMetaAccountRepository(for:sortDescriptors:) instead")
    func createRepository() -> AnyDataProviderRepository<fearless.MetaAccountModel> {
        createMetaAccountRepository(for: nil, sortDescriptors: [])
    }

    @available(*, deprecated, message: "Use createMetaAccountRepository(for:sortDescriptors:) instead")
    func createAccountRepository(
        for _: fearless.SNAddressType
    ) -> AnyDataProviderRepository<fearless.MetaAccountModel> {
        createMetaAccountRepository(for: nil, sortDescriptors: [])
    }
}
