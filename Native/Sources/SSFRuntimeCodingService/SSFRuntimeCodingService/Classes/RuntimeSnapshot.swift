import Foundation
import SSFUtils

public struct RuntimeSnapshot {
    public let typeRegistryCatalog: TypeRegistryCatalogProtocol
    public let specVersion: UInt32
    public let txVersion: UInt32
    public let metadata: RuntimeMetadata

    public init(
        typeRegistryCatalog: TypeRegistryCatalogProtocol,
        specVersion: UInt32,
        txVersion: UInt32,
        metadata: RuntimeMetadata
    ) {
        self.typeRegistryCatalog = typeRegistryCatalog
        self.specVersion = specVersion
        self.txVersion = txVersion
        self.metadata = metadata
    }

    public var runtimeSpecVersion: RuntimeSpecVersion {
        RuntimeSpecVersion(rawValue: specVersion) ?? RuntimeSpecVersion.defaultVersion
    }
}
