import Foundation
import SSFUtils
import SSFRuntimeCodingService

final class AppRuntimeCoderFactory: RuntimeCoderFactoryProtocol {
    private let catalog: TypeRegistryCatalogProtocol
    let specVersion: UInt32
    let txVersion: UInt32
    let metadata: RuntimeMetadata

    init(snapshot: RuntimeSnapshot) {
        catalog = snapshot.typeRegistryCatalog
        specVersion = snapshot.specVersion
        txVersion = snapshot.txVersion
        metadata = snapshot.metadata
    }

    func createEncoder() -> DynamicScaleEncoding {
        DynamicScaleEncoder(registry: catalog, version: UInt64(specVersion))
    }

    func createDecoder(from data: Data) throws -> DynamicScaleDecoding {
        try DynamicScaleDecoder(data: data, registry: catalog, version: UInt64(specVersion))
    }
}
