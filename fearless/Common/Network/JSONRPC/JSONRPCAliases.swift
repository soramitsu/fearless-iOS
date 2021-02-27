import Foundation
import RobinHood

typealias RuntimeVersionUpdate = JSONRPCSubscriptionUpdate<RuntimeVersion>
typealias StorageSubscriptionUpdate = JSONRPCSubscriptionUpdate<StorageUpdate>
typealias JSONRPCQueryOperation = JSONRPCOperation<[[String]], [StorageUpdate]>
typealias SuperIdentityWrapper = CompoundOperationWrapper<[StorageResponse<SuperIdentity>]>
typealias SuperIdentityOperation = BaseOperation<[StorageResponse<SuperIdentity>]>
typealias IdentityWrapper = CompoundOperationWrapper<[StorageResponse<Identity>]>
typealias SlashingSpansWrapper = CompoundOperationWrapper<[StorageResponse<SlashingSpans>]>
typealias UnappliedSlashesWrapper = CompoundOperationWrapper<[StorageResponse<[UnappliedSlash]>]>
