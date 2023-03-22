import Foundation
import FearlessUtils

struct RuntimeSnapshot {
    let localCommonHash: String?
    let localChainTypes: Data?
    let typeRegistryCatalog: TypeRegistryCatalogProtocol
    let specVersion: UInt32
    let txVersion: UInt32
    let metadata: RuntimeMetadata

    var runtimeSpecVersion: RuntimeSpecVersion {
        RuntimeSpecVersion(rawValue: specVersion) ?? RuntimeSpecVersion.defaultVersion
    }
}
