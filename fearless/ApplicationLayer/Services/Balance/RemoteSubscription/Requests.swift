import Foundation
import SSFStorageQueryKit
import SSFModels

enum AccountInfoStorageResponseValueRegistry: String {
    case accountInfo = "AccountInfo"
    case orml = "OrmlAccountInfo"
    case equilibrium = "EquilibriumAccountInfo"
    case asset = "AssetAccount"
}

struct AccountInfoStorageRequest: MixStorageRequest {
    typealias Response = AccountInfo
    let parametersType: MixStorageRequestParametersType
    let storagePath: any StorageCodingPathProtocol
    let requestId: String
}

struct OrmlAccountInfoStorageRequest: MixStorageRequest {
    typealias Response = OrmlAccountInfo
    let parametersType: MixStorageRequestParametersType
    let storagePath: any StorageCodingPathProtocol
    let requestId: String
}

struct EquilibriumAccountInfotorageRequest: MixStorageRequest {
    typealias Response = EquilibriumAccountInfo
    let parametersType: MixStorageRequestParametersType
    let storagePath: any StorageCodingPathProtocol
    let requestId: String
}

struct AssetAccountStorageRequest: MixStorageRequest {
    typealias Response = AssetAccount
    let parametersType: MixStorageRequestParametersType
    let storagePath: any StorageCodingPathProtocol
    let requestId: String
}
