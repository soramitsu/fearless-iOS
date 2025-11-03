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
typealias RuntimeMetadataItem = SSFModels.RuntimeMetadataItem
