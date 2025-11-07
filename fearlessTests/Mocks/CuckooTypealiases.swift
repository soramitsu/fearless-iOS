// These typealiases disambiguate model names used in generated Cuckoo mocks
// where both the app module and SSFModels export similarly named types.

@testable import fearless

// Disambiguation for models/protocols overlapping with SSF modules
// App models
typealias MetaAccountModel = fearless.MetaAccountModel
typealias ManagedMetaAccountModel = fearless.ManagedMetaAccountModel
typealias ChainAccountResponse = fearless.ChainAccountResponse
typealias SNAddressType = fearless.SNAddressType
typealias RuntimeVersion = fearless.RuntimeVersion

// App protocols
typealias ChainRegistryProtocol = fearless.ChainRegistryProtocol
typealias ConnectionPoolProtocol = fearless.ConnectionPoolProtocol
typealias RuntimeProviderPoolProtocol = fearless.RuntimeProviderPoolProtocol
typealias RuntimeSyncServiceProtocol = fearless.RuntimeSyncServiceProtocol
typealias SchedulerProtocol = fearless.SchedulerProtocol
typealias SchedulerDelegate = fearless.SchedulerDelegate

// SSF models
import SSFModels
// Use app's metadata item to match production APIs
typealias RuntimeMetadataItem = fearless.RuntimeMetadataItem
// Additional SSF model bindings used by generated mocks
typealias AssetModel = SSFModels.AssetModel
typealias ChainModel = SSFModels.ChainModel
typealias ChainAsset = SSFModels.ChainAsset
typealias ChainFormat = SSFModels.ChainFormat
typealias AccountId = SSFModels.AccountId
typealias StakingType = SSFModels.StakingType
typealias ChainAssetKey = SSFModels.ChainAssetKey
typealias CryptoType = SSFModels.CryptoType
typealias ChainNodeModel = SSFModels.ChainNodeModel
typealias Currency = SSFModels.Currency
typealias PriceData = SSFModels.PriceData
