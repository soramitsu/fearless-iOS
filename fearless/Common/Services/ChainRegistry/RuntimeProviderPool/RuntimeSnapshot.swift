import Foundation
import FearlessUtils

struct RuntimeSnapshot {
    let localBaseHash: String?
    let localNetworkHash: String?
    let typeRegistryCatalog: TypeRegistryCatalogProtocol
    let specVersion: UInt32
    let txVersion: UInt32
    let metadata: RuntimeMetadata
}
