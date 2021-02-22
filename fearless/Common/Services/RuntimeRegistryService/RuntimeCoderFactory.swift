import Foundation
import FearlessUtils

protocol RuntimeCoderFactoryProtocol {
    var specVersion: UInt32 { get }
    var txVersion: UInt32 { get }
    var metadata: RuntimeMetadata { get }

    func createEncoder() -> DynamicScaleEncoding
    func createDecoder(from data: Data) throws -> DynamicScaleDecoding
}

final class RuntimeCoderFactory: RuntimeCoderFactoryProtocol {
    let catalog: TypeRegistryCatalogProtocol
    let specVersion: UInt32
    let txVersion: UInt32
    let metadata: RuntimeMetadata

    init(catalog: TypeRegistryCatalogProtocol, specVersion: UInt32, txVersion: UInt32, metadata: RuntimeMetadata) {
        self.catalog = catalog
        self.specVersion = specVersion
        self.txVersion = txVersion
        self.metadata = metadata
    }

    func createEncoder() -> DynamicScaleEncoding {
        DynamicScaleEncoder(registry: catalog, version: UInt64(specVersion))
    }

    func createDecoder(from data: Data) throws -> DynamicScaleDecoding {
        try DynamicScaleDecoder(data: data, registry: catalog, version: UInt64(specVersion))
    }
}
