import Foundation
@testable import fearless
import SSFModels
import SSFRuntimeCodingService
import FearlessUtils

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
