import Foundation
import SSFUtils
import SSFRuntimeCodingService
import BigInt

struct AssetHubSignedExtensions {
    let factory: RuntimeCoderFactoryProtocol
    let genesis: Data
    let block: Data
    let era: Era
    let nonce: UInt32
    let tip: BigUInt

    func encode() throws -> (extra: Data, additional: Data) {
        switch era {
        case .immortal:
            guard block == genesis else { throw EraCodingError.phaseAndPeriodMismatch }
        case let .mortal(period, phase):
            guard period >= 4, period <= 65536, period.nonzeroBitCount == 1 else { throw EraCodingError.invalidPeriod }
            guard phase < period, phase % max(period >> 12, 1) == 0 else { throw EraCodingError.phaseAndPeriodMismatch }
        }
        guard let metadata = factory.metadata.extrinsic as? RuntimeMetadataV14.ExtrinsicMetadata,
              metadata.version == 4, genesis.count == 32, block.count == 32 else {
            throw ExtrinsicBuilderError.unsupportedSignedExtension("Asset Hub requires metadata-backed v4 extensions")
        }
        var extra = Data()
        var additional = Data()
        var identifiers = Set<String>()
        for item in metadata.signedExtensions {
            guard identifiers.insert(item.identifier).inserted else {
                throw ExtrinsicBuilderError.unsupportedSignedExtension(item.identifier)
            }
            let values = try bytes(for: item.identifier)
            try validate(values.extra, type: item.type, identifier: item.identifier)
            try validate(values.additional, type: item.additionalSigned, identifier: item.identifier)
            extra.append(values.extra)
            additional.append(values.additional)
        }
        guard ["CheckSpecVersion", "CheckTxVersion", "CheckGenesis", "CheckMortality", "CheckNonce", "CheckMetadataHash"]
            .allSatisfy(identifiers.contains),
            identifiers.contains("ChargeAssetTxPayment") || identifiers.contains("ChargeTransactionPayment") else {
            throw ExtrinsicBuilderError.unsupportedSignedExtension("Missing required Asset Hub extension")
        }
        return (extra, additional)
    }

    private func bytes(for identifier: String) throws -> (extra: Data, additional: Data) {
        switch identifier {
        case "CheckSpecVersion": return (Data(), try factory.specVersion.scaleEncoded())
        case "CheckTxVersion": return (Data(), try factory.txVersion.scaleEncoded())
        case "CheckGenesis": return (Data(), genesis)
        case "CheckMortality": return (try era.scaleEncoded(), block)
        case "CheckNonce": return (try BigUInt(nonce).scaleEncoded(), Data())
        case "ChargeTransactionPayment": return (try tip.scaleEncoded(), Data())
        case "ChargeAssetTxPayment": return (try tip.scaleEncoded() + Data([0]), Data())
        case "CheckMetadataHash": return (Data([0]), Data([0]))
        default:
            // An unrecognized extension is allowed only if BOTH metadata types encode no bytes.
            return (Data(), Data())
        }
    }

    private func validate(_ bytes: Data, type: BigUInt, identifier: String) throws {
        do {
            let name = try factory.metadata.schemaResolver.typeName(for: type)
            let decoder = try factory.createDecoder(from: bytes)
            let value = try decoder.read(type: name)
            let encoder = factory.createEncoder()
            try encoder.append(json: value, type: name)
            guard try encoder.encode() == bytes else {
                throw ExtrinsicBuilderError.unsupportedSignedExtension(identifier)
            }
        } catch {
            throw ExtrinsicBuilderError.unsupportedSignedExtension(identifier)
        }
    }
}
