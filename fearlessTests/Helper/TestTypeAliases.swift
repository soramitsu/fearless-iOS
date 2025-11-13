import Foundation
@testable import fearless
import SSFModels
import SSFRuntimeCodingService

// Disambiguate model types between fearless and SSFModels in tests
typealias MetaAccountModel = fearless.MetaAccountModel
typealias ChainAccountResponse = fearless.ChainAccountResponse
typealias ChainAccountInfo = fearless.ChainAccountInfo
typealias ChainModel = SSFModels.ChainModel
typealias ChainAsset = SSFModels.ChainAsset
typealias AssetModel = SSFModels.AssetModel
typealias RuntimeProviderProtocol = SSFRuntimeCodingService.RuntimeProviderProtocol
