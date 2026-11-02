import Foundation
import SSFUtils
import SSFRuntimeCodingService
import SSFModels
import IrohaCrypto
import BigInt

enum AssetHubExtrinsicBuilderError: Error {
    case payloadChangedDuringSigning
}

/// App-owned v4 builder for the Asset Hub staking genesis hashes. The shared encoder skips any signed extension it
/// does not know; this one checks every extension against the runtime's metadata and refuses one that would carry
/// bytes it cannot supply, so a runtime upgrade fails before anything is signed.
final class AssetHubExtrinsicBuilder: ExtrinsicBuilderProtocol {
    private struct BatchArguments: Codable { let calls: [JSON] }
    private let factory: RuntimeCoderFactoryProtocol
    private let genesis: Data
    private var block: Data
    private var calls: [JSON] = []
    private var address: JSON?
    private var nonce: UInt32?
    private var era = Era.immortal
    private var tip = BigUInt.zero
    private var signature: JSON?
    private var revision = UUID()
    private var atomic = true

    init(factory: RuntimeCoderFactoryProtocol, genesisHash: String) throws {
        let genesis = try Data(hexStringSSF: genesisHash)
        guard AssetHubStakingRoute.staking(on: genesis.toHex()) != nil else {
            throw StakingServiceFactoryError.stakingUnavailable
        }
        self.factory = factory
        self.genesis = genesis
        block = genesis
    }

    func with<A: Codable>(address: A) throws -> Self {
        self.address = try address.toScaleCompatibleJSON()
        invalidateSignature()
        return self
    }

    func with(nonce: UInt32) -> Self {
        self.nonce = nonce
        invalidateSignature()
        return self
    }

    func with(era: Era, blockHash: String) -> Self {
        self.era = era
        block = (try? Data(hexStringSSF: blockHash)) ?? Data()
        invalidateSignature()
        return self
    }

    func with(tip: BigUInt) -> Self {
        self.tip = tip
        invalidateSignature()
        return self
    }

    func with(appId: BigUInt) -> Self {
        // Asset Hub has no app-id extension; reject a nonzero value at encoding.
        unsupportedAppId = appId != 0
        invalidateSignature()
        return self
    }

    private var unsupportedAppId = false

    func with(shouldUseAtomicBatch: Bool) -> Self {
        atomic = shouldUseAtomicBatch
        invalidateSignature()
        return self
    }

    func adding<T: RuntimeCallable>(call: T) throws -> Self {
        calls.append(try call.toScaleCompatibleJSON())
        invalidateSignature()
        return self
    }

    func adding(rawCall: Data) throws -> Self {
        let decoded = try factory.createDecoder(from: rawCall).read(type: GenericType.call.name)
        let encoder = factory.createEncoder()
        try encoder.append(json: decoded, type: GenericType.call.name)
        guard try encoder.encode() == rawCall else { throw ExtrinsicBuilderError.missingCall }
        calls.append(decoded)
        invalidateSignature()
        return self
    }

    func signing(
        by signer: (Data) throws -> Data,
        of type: CryptoType,
        using _: DynamicScaleEncoding,
        metadata _: RuntimeMetadata
    ) throws -> Self {
        guard address != nil else { throw ExtrinsicBuilderError.missingAddress }
        signature = nil
        let signingRevision = revision
        let bytes = try signer(payload())
        guard revision == signingRevision else { throw AssetHubExtrinsicBuilderError.payloadChangedDuringSigning }
        let value: MultiSignature
        switch type {
        case .sr25519:
            guard bytes.count == 64 else { throw ExtrinsicSignatureNodeError.invalidParams }
            value = .sr25519(data: bytes)
        case .ed25519:
            guard bytes.count == 64 else { throw ExtrinsicSignatureNodeError.invalidParams }
            value = .ed25519(data: bytes)
        case .ecdsa:
            guard bytes.count == 65 else { throw ExtrinsicSignatureNodeError.invalidParams }
            value = .ecdsa(data: bytes)
        }
        signature = try value.toScaleCompatibleJSON()
        return self
    }

    func build(encodingBy _: DynamicScaleEncoding, metadata _: RuntimeMetadata) throws -> Data {
        let encoder = factory.createEncoder()
        if let signature = signature {
            guard let address = address else { throw ExtrinsicBuilderError.missingAddress }
            try encoder.append(encodable: UInt8(0x84))
            try encoder.append(json: address, type: KnownType.address.name)
            try encoder.append(json: signature, type: factory.metadata.signatureType)
            try encoder.appendBytes(json: .stringValue(extensions().extra.toHex()))
        } else {
            try encoder.append(encodable: UInt8(4))
        }
        try encoder.append(json: preparedCall(), type: GenericType.call.name)
        let body = try encoder.encode()
        let outer = factory.createEncoder()
        try outer.append(encodable: body)
        return try outer.encode()
    }

    func buildSignature(encodingBy _: DynamicScaleEncoding, metadata _: RuntimeMetadata) throws -> Data {
        try payload()
    }

    private func extensions() throws -> (extra: Data, additional: Data) {
        guard !unsupportedAppId else { throw ExtrinsicBuilderError.unsupportedSignedExtension("CheckAppId") }
        guard let nonce = nonce else { throw ExtrinsicBuilderError.missingNonce }
        return try AssetHubSignedExtensions(factory: factory, genesis: genesis, block: block, era: era, nonce: nonce, tip: tip).encode()
    }

    private func invalidateSignature() {
        signature = nil
        revision = UUID()
    }

    private func preparedCall() throws -> JSON {
        guard let first = calls.first else { throw ExtrinsicBuilderError.missingCall }
        guard calls.count > 1 else { return first }
        let name = atomic ? "batch_all" : "batch"
        guard try factory.metadata.getFunction(from: "Utility", with: name) != nil else {
            throw ExtrinsicBuilderError.unsupportedBatch
        }
        return try RuntimeCall(moduleName: "Utility", callName: name, args: BatchArguments(calls: calls)).toScaleCompatibleJSON()
    }

    private func payload() throws -> Data {
        let encoder = factory.createEncoder()
        let values = try extensions()
        try encoder.append(json: preparedCall(), type: GenericType.call.name)
        try encoder.appendBytes(json: .stringValue(values.extra.toHex()))
        try encoder.appendBytes(json: .stringValue(values.additional.toHex()))
        let bytes = try encoder.encode()
        return try bytes.count > 256 ? bytes.blake2b32() : bytes
    }
}
