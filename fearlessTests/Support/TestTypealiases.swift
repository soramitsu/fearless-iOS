import Foundation
@testable import fearless
import SSFModels
import SSFChainRegistry
import SSFUtils

// Disambiguate types that exist in multiple modules.
public typealias ChainAccountResponse = fearless.ChainAccountResponse
public typealias MetaAccountModel = fearless.MetaAccountModel
public typealias ManagedMetaAccountModel = fearless.ManagedMetaAccountModel
public typealias SNAddressType = fearless.SNAddressType
public typealias SchedulerProtocol = fearless.SchedulerProtocol
public typealias SchedulerDelegate = fearless.SchedulerDelegate
public typealias ChainRegistryProtocol = fearless.ChainRegistryProtocol
public typealias ConnectionPoolProtocol = fearless.ConnectionPoolProtocol
public typealias RuntimeProviderPoolProtocol = fearless.RuntimeProviderPoolProtocol
public typealias RuntimeSyncServiceProtocol = fearless.RuntimeSyncServiceProtocol
public typealias RuntimeVersion = fearless.RuntimeVersion
public typealias RuntimeMetadataItem = fearless.RuntimeMetadataItem
public typealias ChainModel = fearless.ChainModel
public typealias PriceData = SSFModels.PriceData
