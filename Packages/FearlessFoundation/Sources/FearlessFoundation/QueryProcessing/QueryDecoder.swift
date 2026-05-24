import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol QueryDecoderProtocol {
    func decode<T>(_ modelClass: T.Type, query: String) throws -> T where T: Decodable
}

public enum QueryDecoderError: Error {
    case emptyKeyValueSeparator(fragment: String)
}

public final class QueryDecoder {
    public static let paramSeparator = "&"
    public static let keyValueSeparator = "="

    lazy private var jsonEncoder = JSONEncoder()
    lazy private var jsonDecoder = JSONDecoder()

    public init() {}

    public func decode<T>(_ modelClass: T.Type, query: String) throws -> T where T: Decodable {
        let container = try query.components(separatedBy: QueryDecoder.paramSeparator)
            .reduce(into: [String: String]()) { (container, param) in
            guard let separatorIndex = param.firstIndex(of: Character(QueryDecoder.keyValueSeparator)) else {
                throw QueryDecoderError.emptyKeyValueSeparator(fragment: param)
            }

            let key: String

            if param.startIndex < separatorIndex {
                key = String(param[param.startIndex..<separatorIndex])
            } else {
                key = ""
            }

            let value: String

            let valueStart = param.index(after: separatorIndex)

            if valueStart < param.endIndex {
                value = String(param[valueStart..<param.endIndex])
            } else {
                value = ""
            }

            container[key] = value
        }

        let encodedData = try jsonEncoder.encode(container)

        return try jsonDecoder.decode(modelClass, from: encodedData)
    }
}
