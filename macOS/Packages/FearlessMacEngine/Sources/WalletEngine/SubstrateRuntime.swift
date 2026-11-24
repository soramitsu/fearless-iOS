import BigInt
import Foundation
import SSFModels
import SSFUtils
import WalletCore

struct SubstrateRuntime {
    let metadata: RuntimeMetadata
    let registry: TypeRegistryCatalog
    let spec, transaction: UInt32

    init(data: Data, spec: UInt32, transaction: UInt32) throws {
        guard data.starts(with: [109, 101, 116, 97, 14])
        else { throw WalletError.network("Node did not supply V14 runtime metadata.") }
        self.spec = spec
        self.transaction = transaction
        metadata = try RuntimeMetadata(scaleDecoder: ScaleDecoder(data: data))
        registry = try TypeRegistryCatalog.createFromTypeDefinition(
            Data(#"{"types":{"Index":"u32","Balance":"u128"}}"#.utf8), runtimeMetadata: metadata,
            usedRuntimePaths: ["System": ["Account", "Events"], "Assets": ["Account", "Asset"], "Balances": []]
        )
    }

    private func encoder() -> DynamicScaleEncoder {
        DynamicScaleEncoder(registry: registry, version: UInt64(spec))
    }

    func storage(_ module: String, _ name: String, keys: [Data]) throws -> (key: String, type: String) {
        guard let pallet = metadata.modules.first(where: { $0.name == module }), let prefix = pallet.storage?.prefix,
              let entry = metadata.getStorageMetadata(in: module, storageName: name)
        else { throw WalletError.unsupportedAsset }
        let hashers = try entry.type.hashers(schemaResolver: metadata.schemaResolver)
        let key = keys.isEmpty ? try StorageKeyFactory().createStorageKey(moduleName: prefix, storageName: name) :
            try StorageKeyFactory().createStorageKey(
                moduleName: prefix,
                storageName: name,
                keys: keys,
                hashers: hashers
            )
        return try (key.toHex(includePrefix: true), entry.type.typeName(using: metadata.schemaResolver))
    }

    func decode(_ data: Data, type: String) throws -> JSON {
        let decoder = try DynamicScaleDecoder(data: data, registry: registry, version: UInt64(spec))
        let value = try decoder.read(type: type)
        guard decoder.remained == 0 else { throw WalletError.network("Unexpected SCALE value length.") }
        return value
    }

    var existentialDeposit: BigUInt {
        get throws {
            guard let ed = metadata.getConstant(in: "Balances", constantName: "ExistentialDeposit") else {
                throw WalletError.network("Runtime has no existential deposit.")
            }
            return try Self.number(decode(ed.value, type: ed.type(using: metadata.schemaResolver)))
        }
    }

    static func number(_ json: JSON?) throws -> BigUInt {
        guard let str = json?.stringValue,
              let value = BigUInt(str) else { throw WalletError.network("Invalid runtime balance.") }
        return value
    }

    struct SigningContext {
        let sender: Data
        let nonce: UInt32
        let height: UInt64
        let block: String
    }

    func builder(
        dest: Data, asset: AssetID, amount: BigUInt, keepAlive: Bool,
        context: SigningContext
    ) throws -> ExtrinsicBuilder {
        // The Native v4 builder handles the named data-bearing extensions below. Extra extensions
        // are safe to omit only if both their explicit and implicit SCALE types occupy zero bytes.
        guard let ext = metadata.extrinsic as? RuntimeMetadataV14.ExtrinsicMetadata else {
            throw WalletError.transferRejected("Unsupported extrinsic metadata.")
        }
        guard dest.count == 32, let pins = try Catalog.chain(asset.chainID).signing, ext.version == 4 else {
            throw WalletError.transferRejected("Unsupported transfer encoding.")
        }
        var order: [String] = []
        for item in ext.signedExtensions {
            if pins.extensions.contains(item.identifier) {
                order.append(item.identifier)
                guard try metadata.schemaResolver.typeMetadata(for: item.type).path.last == item.identifier else {
                    throw WalletError.transferRejected("Unrecognized runtime type for \(item.identifier).")
                }
            } else if try !isEmpty(item.type) || !isEmpty(item.additionalSigned) {
                throw WalletError.transferRejected("Unsupported signed extension \(item.identifier).")
            }
        }
        guard order == pins.extensions else {
            throw WalletError.transferRejected("Unexpected signed extension order.")
        }
        let builder = try ExtrinsicBuilder(
            specVersion: spec,
            transactionVersion: transaction,
            genesisHash: "0x" + asset.chainID.rawValue
        )
        .with(address: MultiAddress.accoundId(context.sender)).with(nonce: context.nonce)
        .with(era: .mortal(period: 64, phase: context.height % 64), blockHash: context.block)
        let destination = try MultiAddress.accoundId(dest).toScaleCompatibleJSON()
        let call: RuntimeCall<[String: JSON]>
        let expected = ScaleEncoder()
        if asset.isNative {
            expected.appendRaw(data: Data([pins.balances, keepAlive ? pins.keepAlive : pins.allowDeath]))
            call = RuntimeCall(
                moduleName: "Balances",
                callName: keepAlive ? "transfer_keep_alive" : "transfer_allow_death",
                args: ["dest": destination, "value": .stringValue(String(amount))]
            )
        } else if asset.key.hasPrefix("asset:"), let index = UInt32(asset.key.dropFirst(6)) {
            guard let pallet = pins.assets, let variant = pins.assetKeepAlive else { throw WalletError.unsupportedAsset }
            expected.appendRaw(data: Data([pallet, variant]))
            try BigUInt(index).encode(scaleEncoder: expected)
            call = RuntimeCall(
                moduleName: "Assets",
                callName: "transfer_keep_alive",
                args: ["id": .stringValue(String(index)), "target": destination, "amount": .stringValue(String(amount))]
            )
        } else {
            throw WalletError.unsupportedAsset
        }
        expected.appendRaw(data: Data([0]) + dest)
        try amount.encode(scaleEncoder: expected)
        let dynamic = encoder()
        try dynamic.append(json: call.toScaleCompatibleJSON(), type: GenericType.call.name)
        guard try dynamic.encode() == expected.encode() else {
            throw WalletError.transferRejected("Runtime transfer call differs from the reviewed encoding.")
        }
        return try builder.adding(call: call)
    }

    private func isEmpty(_ index: BigUInt, depth: Int = 0) throws -> Bool {
        guard depth < 16 else { return false }
        switch try metadata.schemaResolver.typeMetadata(for: index).def {
        case let .tuple(values): return try values.allSatisfy { try isEmpty($0, depth: depth + 1) }
        case let .composite(composite): return try composite.fields
            .allSatisfy { try isEmpty($0.type, depth: depth + 1) }
        default: return false
        }
    }

    func payload(_ builder: ExtrinsicBuilder) throws -> Data {
        try builder.buildSignature(encodingBy: encoder(), metadata: metadata)
    }

    func encode(_ builder: ExtrinsicBuilder, crypto: WalletCore.CryptoType, signature: Data) throws -> Data {
        try builder.signing(by: { _ in signature }, of: crypto.native, using: encoder(), metadata: metadata)
            .build(encodingBy: encoder(), metadata: metadata)
    }
}

extension NetworkServices {
    func runtime(_ id: ChainID, block: String) async throws -> SubstrateRuntime {
        guard let version = try await rpc(id, "state_getRuntimeVersion", [block]) as? [String: Any],
              let spec = version["specVersion"] as? UInt32, let tx = version["transactionVersion"] as? UInt32 else {
            throw WalletError.network("Invalid runtime version.")
        }
        let snapshot = MetadataSnapshot.all.first {
            $0.genesis == id.rawValue && $0.specVersion == spec && $0.transactionVersion == tx
        }
        // Check the requested block even on a registry cache hit.
        if let snapshot {
            guard let hash = try await rpc(id, "state_getStorageHash", ["0x3a636f6465", block]) as? String,
                  hash.lowercased() == snapshot.codeHash else {
                throw WalletError.network("Runtime code differs from the bundled snapshot.")
            }
        }
        if let runtime = runtimes[id], runtime.spec == spec, runtime.transaction == tx {
            return runtime
        }
        let versionKey = UInt64(spec) << 32 | UInt64(tx)
        if let (version, task) = loading[id], version == versionKey {
            return try await task.value
        }
        let task = Task {
            if let snapshot {
                return try await Task.detached {
                    try SubstrateRuntime(data: snapshot.bytes(for: snapshot.codeHash), spec: spec, transaction: tx)
                }.value
            }
            guard let hex = try await rpc(id, "state_getMetadata", [block]) as? String else {
                throw WalletError.network("Runtime metadata unavailable.")
            }
            return try await Task.detached {
                try SubstrateRuntime(data: Data(hexStringSSF: hex), spec: spec, transaction: tx)
            }.value
        }
        loading[id] = (versionKey, task)
        defer {
            if loading[id]?.0 == versionKey {
                loading[id] = nil
            }
        }
        let runtime = try await task.value
        runtimes[id] = runtime
        return runtime
    }

    func blockHash(_ id: ChainID) async throws -> String {
        guard let hash = try await rpc(id, "chain_getFinalizedHead") as? String,
              hash.count == 66 else { throw WalletError.network("Missing finalized block.") }
        return hash
    }

    func value(
        _ runtime: SubstrateRuntime,
        _ id: ChainID,
        block: String,
        module: String,
        name: String,
        keys: [Data]
    ) async throws -> JSON? {
        let entry = try runtime.storage(module, name, keys: keys)
        let value = try await rpc(id, "state_getStorage", [entry.key, block])
        if value is NSNull {
            return nil
        }
        guard let hex = value as? String else { throw WalletError.network("Invalid storage response.") }
        return try runtime.decode(Data(hexStringSSF: hex), type: entry.type)
    }
}
