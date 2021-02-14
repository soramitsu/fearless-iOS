import Foundation
import FearlessUtils

protocol RuntimeCoderFactoryProtocol {
    func createEncoder() -> DynamicScaleEncoding
    func createDecoder(from data: Data) throws -> DynamicScaleDecoding
}

final class RuntimeCoderFactory: RuntimeCoderFactoryProtocol {
    let catalog: TypeRegistryCatalogProtocol
    let version: UInt32

    init(catalog: TypeRegistryCatalogProtocol, version: UInt32) {
        self.catalog = catalog
        self.version = version
    }

    func createEncoder() -> DynamicScaleEncoding {
        DynamicScaleEncoder(registry: catalog, version: UInt64(version))
    }

    func createDecoder(from data: Data) throws -> DynamicScaleDecoding {
        try DynamicScaleDecoder(data: data, registry: catalog, version: UInt64(version))
    }
}
