import Foundation

public enum GenericCallNodeError: Error {
    case unexpectedParams
    case unexpectedCallModule(value: UInt64)
    case unexpectedCallFunction(value: UInt64)
    case argumentsNotMatchingParams(arguments: [String], params: [JSON])
    case unexpectedDecodedModule
    case unexpectedDecodedFunction
}

public class GenericCallNode: Node {
    public var typeName: String { GenericType.call.name }
    public let runtimeMetadata: RuntimeMetadata

    public init(runtimeMetadata: RuntimeMetadata) {
        self.runtimeMetadata = runtimeMetadata
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        let call = try value.plainMap(to: RuntimeCall<JSON>.self)

        guard let function = try runtimeMetadata.getFunction(
            from: call.moduleName,
            with: call.callName
        ),
            let moduleIndex = runtimeMetadata.getModuleIndex(call.moduleName),
            let callIndex = try runtimeMetadata.getCallIndex(
                in: call.moduleName,
                callName: call.callName
            ) else
        {
            throw GenericCallNodeError.unexpectedParams
        }

        guard let args = call.args.dictValue, function.arguments.count == args.count else {
            throw GenericCallNodeError.unexpectedParams
        }

        try encoder.appendU8(json: .stringValue(String(moduleIndex)))
        try encoder.appendU8(json: .stringValue(String(callIndex)))

        for index in 0 ..< function.arguments.count {
            let arg = function.arguments[index]
            guard var param = args[arg.name] else {
                throw GenericCallNodeError.unexpectedParams
            }

            // Basically, all Substrate networks use "sp_runtime::multiaddress::MultiAddress" enum
            // for destination
            // But some like Basilisk, use "sp_core::crypto::AccountId32" ([u8;32]) directly instead
            // Moonbeam/Moonriver use AccountId20 ([u8;20])
            let addressIdTypes = KnownType.addressIdTypes.map { $0.name }
            if addressIdTypes.contains(arg.type), arg.name == "dest" {
                guard let id = param.arrayValue, id.count == 2,
                      let idParam = id[1].arrayValue else
                {
                    assertionFailure()
                    throw GenericCallNodeError.unexpectedParams
                }

                param = .arrayValue(idParam)
            }

            try encoder.append(json: param, type: arg.type)
        }
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        guard let callModuleString = try (decoder.readU8()).stringValue,
              let moduleIndex = Int(callModuleString) else
        {
            throw GenericCallNodeError.unexpectedDecodedModule
        }

        guard let callFunctionString = try (decoder.readU8()).stringValue,
              let callIndex = UInt8(callFunctionString) else
        {
            throw GenericCallNodeError.unexpectedDecodedFunction
        }

        guard let module = runtimeMetadata.modules.first(where: { $0.index == moduleIndex }) else {
            throw GenericCallNodeError.unexpectedCallModule(value: UInt64(moduleIndex))
        }

        guard let call = try runtimeMetadata.getFunction(in: module, at: callIndex) else {
            throw GenericCallNodeError.unexpectedCallFunction(value: UInt64(callIndex))
        }

        let params = try call.arguments.reduce(into: [String: JSON]()) { result, item in
            let param = try decoder.read(type: item.type)
            result[item.name] = param
        }

        let result = RuntimeCall(moduleName: module.name, callName: call.name, args: params)

        return try result.toScaleCompatibleJSON()
    }
}
