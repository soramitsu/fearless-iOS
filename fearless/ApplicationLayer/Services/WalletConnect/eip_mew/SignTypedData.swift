//
//  SignTypedData.swift
//  MEWwalletKit
//
//  Created by Nail Galiaskarov on 3/16/21.
//  Copyright © 2021 MyEtherWallet Inc. All rights reserved.
//

import Foundation
import CryptoSwift

public enum TypedMessageSignError: Error {
    case invalidVersion
    case invalidData
    case unknown(String)

    func messageError() -> String {
        switch self {
        case let .unknown(string):
            return string
        case .invalidVersion:
            return "Invalid version"
        case .invalidData:
            return "Invalid data"
        }
    }
}

public enum SignTypedDataVersion {
    // swiftlint:disable:next identifier_name
    case v1, v3, v4
}

public struct MessageTypeProperty: Codable {
    public let name: String
    public let type: String
}

public struct TypedMessageDomain: Codable {
    public let name: String?
    public let version: String?
    public let chainId: Int?
    public let verifyingContract: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case version
        case chainId
        case verifyingContract
    }

    public init(
        name: String?,
        version: String?,
        chainId: Int?,
        verifyingContract: String?
    ) {
        self.name = name
        self.version = version
        self.chainId = chainId
        self.verifyingContract = verifyingContract
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decodeIfPresent(String.self, forKey: .name)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        if let chainId = try? container.decodeIfPresent(Int.self, forKey: .chainId) {
            self.chainId = chainId
        } else if let chainId = try container.decodeIfPresent(String.self, forKey: .chainId) {
            self.chainId = Int(chainId)
        } else {
            chainId = nil
        }
        verifyingContract = try container.decodeIfPresent(String.self, forKey: .verifyingContract)
    }

    func encoded() -> [String: AnyObject] {
        guard let data = try? JSONEncoder().encode(self) else {
            return [:]
        }

        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        return (json as? [String: AnyObject]) ?? [:]
    }
}

public typealias MessageTypes = [String: [MessageTypeProperty]]

public struct SignedMessagePayload {
    public let data: TypedMessage
    public let signature: String?

    public init(
        data: TypedMessage,
        signature: String?
    ) {
        self.data = data
        self.signature = signature
    }
}

public struct TypedMessage {
    public let types: MessageTypes
    public let primaryType: String
    public let domain: TypedMessageDomain
    public let message: [[String: AnyObject]]
    public let version: SignTypedDataVersion
}

public extension TypedMessage {
    private enum CodingKeys: String {
        case types
        case primaryType
        case domain
        case message
    }

    init(json: Any, version: SignTypedDataVersion) throws {
        self.version = version
        switch version {
        case .v1:
            guard let json = json as? [[String: AnyObject]] else { throw TypedMessageSignError.invalidData }
            types = [:]
            domain = .init(name: nil, version: nil, chainId: nil, verifyingContract: nil)
            primaryType = ""
            message = json

        case .v3, .v4:
            guard let json = json as? [String: Any] else { throw TypedMessageSignError.invalidData }
            guard let primaryType = json[CodingKeys.primaryType.rawValue] as? String else { throw TypedMessageSignError.invalidData }

            let types = (json[CodingKeys.types.rawValue] as? [String: Any]) ?? [:]
            var messageTypes = MessageTypes()
            try types.forEach {
                if let json = $0.value as? [[String: Any]] {
                    let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
                    messageTypes[$0.key] = try JSONDecoder().decode([MessageTypeProperty].self, from: data)
                }
            }
            self.types = messageTypes

            self.primaryType = primaryType

            let domain = (json[CodingKeys.domain.rawValue] as? [String: Any]) ?? [:]
            let domainData = try JSONSerialization.data(withJSONObject: domain, options: .prettyPrinted)
            self.domain = try JSONDecoder().decode(TypedMessageDomain.self, from: domainData)

            message = [(json[CodingKeys.message.rawValue] as? [String: AnyObject]) ?? [:]]
        }
    }
}

public func hash(message: TypedMessage, version: SignTypedDataVersion) throws -> Data {
    switch version {
    case .v1:
        let data = try message.message.reduce(Data()) { partialResult, message in
            guard let type = message["type"] as? String, let value = message["value"] else { throw TypedMessageSignError.invalidData }
            let parsedType = try ABITypeParser.parseTypeString(type)
            guard var data = ABIEncoder.convertToData(value, type: parsedType) else { throw TypedMessageSignError.invalidData }
            switch parsedType {
            case let .int(bits: length), let .uint(bits: length), let .bytes(length: length):
                data.setLength(Int(clamping: length / 8))
            default:
                break
            }
            return partialResult + data
        }
        let schema = try message.message.reduce(Data()) { partialResult, message in
            guard let type = message["type"] as? String, let name = message["name"] as? String else { throw TypedMessageSignError.invalidData }
            guard let data = ABIEncoder.convertToData("\(type) \(name)" as AnyObject, type: .string) else { throw TypedMessageSignError.invalidData }
            return partialResult + data
        }

        let sha3schema = schema.sha3(.keccak256) as AnyObject
        let sha3message = data.sha3(.keccak256) as AnyObject

        guard let hash = ABIEncoder.encode(types: [.bytes(length: 32), .bytes(length: 32)], values: [sha3schema, sha3message]) else { throw TypedMessageSignError.invalidData }
        return hash

    case .v3 where message.message.count == 1, .v4 where message.message.count == 1:
        var data = Data(hex: "1901")

        data.append(
            try hashStruct(
                primaryType: "EIP712Domain",
                data: message.domain.encoded(),
                types: message.types,
                version: version
            )
        )

        if message.primaryType != "EIP712Domain" {
            data.append(
                try hashStruct(
                    primaryType: message.primaryType,
                    data: message.message[0],
                    types: message.types,
                    version: version
                )
            )
        }

        return data
    default:
        throw TypedMessageSignError.invalidVersion
    }
}

public func hashStruct(
    primaryType: String,
    data: [String: AnyObject],
    types: MessageTypes,
    version: SignTypedDataVersion
) throws -> Data {
    let data = try encodeData(
        primaryType: primaryType,
        data: data,
        types: types,
        version: version
    )
    return data.sha3(.keccak256)
}

public func encodeData(
    primaryType: String,
    data: [String: AnyObject],
    types: MessageTypes,
    version: SignTypedDataVersion
) throws -> Data {
    var encodedTypes = ["bytes32"]
    var encodedValues: [AnyObject] = [try hashType(primaryType: primaryType, types: types)]

    func encodeField(name: String, type: String, value: AnyObject) throws -> (type: String, value: AnyObject) {
        if types[type] != nil {
            // value ???
            let encodedValue =
                try encodeData(
                    primaryType: type,
                    data: value as? [String: AnyObject] ?? [:],
                    types: types,
                    version: version
                ).sha3(.keccak256)
            return (
                type: "bytes32",
                value: encodedValue.bytes as AnyObject
            )
        }

        if type == "bytes" {
            guard let data = ABIEncoder.convertToData(value, type: .bytes(length: 32)) else {
                throw TypedMessageSignError.unknown("failed to convert value \(value) to data")
            }

            return (type: "bytes32", value: data.sha3(.keccak256).bytes as AnyObject)
        }

        if type == "string" {
            guard let string = value as? String else {
                throw TypedMessageSignError.unknown("failed to convert value \(value) to string")
            }

            let data = string.data(using: .utf8)!

            return (type: "bytes32", value: data.sha3(.keccak256).bytes as AnyObject)
        }

        // TODO: check with metamask test cases v4
        if type.last == "]" {
            guard version == .v4 else {
                throw TypedMessageSignError.unknown("Arrays are unimplemented in encoded data; use v4")
            }

            guard let index = type.lastIndex(of: "[") else {
                throw TypedMessageSignError.unknown("Bad array format")
            }

            let parsedType = String(type[..<index])
            let array: [AnyObject]
            if let objects = value as? [AnyObject] {
                array = objects
            } else {
                array = [AnyObject](arrayLiteral: value)
            }
            let typeValuePairs: [(type: ABI.Element.ParameterType, value: AnyObject)] = try array.map {
                let encoded = try encodeField(name: name, type: parsedType, value: $0)
                let abiType = try ABITypeParser.parseTypeString(encoded.type)
                return (type: abiType, value: encoded.value)
            }

            guard
                let data = ABIEncoder.encode(
                    types: typeValuePairs.map { $0.type },
                    values: typeValuePairs.map { $0.value }
                )
            else {
                throw TypedMessageSignError.unknown("Failed to abi encode")
            }

            return (
                type: "bytes32",
                value: data.sha3(.keccak256).bytes as AnyObject
            )
        }

        return (type: type, value: value)
    }

    for field in types[primaryType]! where data[field.name] != nil {
        let result = try encodeField(
            name: field.name,
            type: field.type,
            value: data[field.name]!
        )
        encodedTypes.append(result.type)
        encodedValues.append(result.value)
    }

    let types = try encodedTypes.map {
        try ABITypeParser.parseTypeString($0)
    }

    guard let encodedData = ABIEncoder.encode(types: types, values: encodedValues) else {
        throw TypedMessageSignError.unknown("Failed to abi encode")
    }
    return encodedData
}

public func hashType(primaryType: String, types: MessageTypes) throws -> AnyObject {
    let encoded = try encodedType(primaryType: primaryType, types: types)
    guard let data = encoded.data(using: .ascii)?.sha3(.keccak256) else {
        throw TypedMessageSignError.unknown("Invalid encoded data: \(encoded)")
    }

    return data.bytes as AnyObject
}

public func encodedType(primaryType: String, types: MessageTypes) throws -> String {
    var result = ""
    var deps = findTypeDependencies(primaryType: primaryType, types: types).filter {
        $0 != primaryType
    }

    deps = [primaryType] + deps.sorted()
    for type in deps {
        guard let children = types[type] else {
            throw TypedMessageSignError.unknown("No type definition specified: \(type)")
        }

        let joined = children
            .map { "\($0.type) \($0.name)" }
            .joined(separator: ",")

        result += "\(type)(\(joined))"
    }

    return result
}

func findTypeDependencies(primaryType: String, types: MessageTypes, results: [String] = []) -> [String] {
    let primaryType = primaryType.match(for: "^\\w*") ?? primaryType
    var results = results

    if results.contains(primaryType) {
        return results
    }

    guard let properties = types[primaryType] else {
        return results
    }

    results.append(primaryType)

    for field in properties {
        for dep in findTypeDependencies(primaryType: field.type, types: types, results: results) {
            if !results.contains(dep) {
                results.append(dep)
            }
        }
    }

    return results
}
