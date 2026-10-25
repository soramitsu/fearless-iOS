/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Protocol is designed to provide an interface for building urls from
 *  a template.
 */

public protocol EndpointBuilderProtocol {
    /**
     *  Setups a set of characters to leave without encoding in final url.
     *
     *  - parameters:
     *    - allowedCharset: Character set to leave without encoding in final url.
     *  - returns: Current instance.
     */

    func withUrlEncoding(allowedCharset: CharacterSet) -> Self

    /**
     *  Creates a url for single parameter.
     *
     *  - parameters:
     *    - value: single parameter to replace in template.
     *  - returns: URL value if success or an error is thrown in case of failure.
     *  - throws: EnpointBuilderError.
     */

    func buildParameterURL(_ value: String) throws -> URL

    /**
     *  Creates a url where each parameter is replaced with correponding value
     *  of encodable object.
     *
     *  - parameters:
     *    - parameters: Encodable object to replace template parameters.
     *  - returns: URL value if success or an error is thrown in case of failure.
     */

    func buildURL<T>(with parameters: T) throws -> URL where T: Encodable

    /**
     *  Creates a string where each parameter is replaced with regex '*' (star)
     *  symbol.
     */
    func buildRegex() throws -> String
}

/**
 *  Enum if designed to define possible error which can occur
 *  during template processing by endpoint builder.
 */

public enum EndpointBuilderError: Error {
    /// Unexpected parameter start symbol found during template parsing.
    case unexpectedParameterStart

    /// Unexpected parameter end symbol found during template parsing.
    case unexpectedParameterEnd

    /// URL can't be created from processed template string.
    case invalidUrl

    /// Can't serialize parameters object to process template string.
    case invalidObject

    /// Parameters object must contain either string or int as fields.
    case paramMustConvertToString

    /// Multiple parameters found in template string but expected only a single one.
    case singleParameterExpected

    /// Can't encode symbols in final url.
    case invalidUrlEncoding
}

/**
 *  Class is designed to provide implementation of ```EndpointBuilderProtocol```.
 *
 *  Template part that should be replaced must be surrounded with a pair of brackets ```{}```.
 *  For example, ```https://google.com/{search}?count={count}```.
 */

public final class EndpointBuilder {
    static let paramStart = Character("{")
    static let paramEnd = Character("}")
    static let regexReplacement: String = "[^/?&]+"
    static let regexSpecialCharacters = CharacterSet(charactersIn: "+?.*")
    static let regexSkipString = "\\"

    /// Template string to build url from.
    public let urlTemplate: String

    private var allowedUrlEncodingCharset: CharacterSet?

    private lazy var encoder = JSONEncoder()

    /**
     *  Initializes endpoint builder.
     *
     *  - parameters:
     *    - urlTemplate: Template to build url from.
     */

    public init(urlTemplate: String) {
        self.urlTemplate = urlTemplate
    }

    private func process(
        urlTemplate: String,
        replacement block: (String) throws -> String
    ) throws -> String {
        var result = String()
        var paramStartIndex: String.Index?

        for index in 0 ..< urlTemplate.count {
            let stringIndex = urlTemplate.index(urlTemplate.startIndex, offsetBy: index)

            if urlTemplate[stringIndex] == EndpointBuilder.paramStart {
                guard paramStartIndex == nil else {
                    throw EndpointBuilderError.unexpectedParameterStart
                }

                paramStartIndex = stringIndex
            } else if urlTemplate[stringIndex] == EndpointBuilder.paramEnd {
                guard let startIndex = paramStartIndex else {
                    throw EndpointBuilderError.unexpectedParameterEnd
                }

                let paramNameStart = urlTemplate.index(after: startIndex)
                let paramNameEnd = urlTemplate.index(before: stringIndex)

                let paramName = String(urlTemplate[paramNameStart ... paramNameEnd])

                let replacement = try block(paramName)
                result.append(replacement)

                paramStartIndex = nil

            } else if paramStartIndex == nil {
                result.append(urlTemplate[stringIndex])
            }
        }

        return result
    }

    private func byEncoding(string: String) throws -> String {
        guard let encodingCharset = allowedUrlEncodingCharset else {
            return string
        }

        guard let encodedString = string
            .addingPercentEncoding(withAllowedCharacters: encodingCharset) else
        {
            throw EndpointBuilderError.invalidUrlEncoding
        }

        return encodedString
    }
}

extension EndpointBuilder: EndpointBuilderProtocol {
    public func withUrlEncoding(allowedCharset: CharacterSet) -> Self {
        allowedUrlEncodingCharset = allowedCharset
        return self
    }

    public func buildParameterURL(_ value: String) throws -> URL {
        var alreadyFilledParam = false

        let urlString = try process(urlTemplate: urlTemplate) { _ in
            guard !alreadyFilledParam else {
                throw EndpointBuilderError.singleParameterExpected
            }

            alreadyFilledParam = true

            return try byEncoding(string: value)
        }

        guard let url = URL(string: urlString) else {
            throw EndpointBuilderError.invalidUrl
        }

        return url
    }

    public func buildURL<T>(with parameters: T) throws -> URL where T: Encodable {
        let data = try encoder.encode(parameters)

        guard let keyValueParam = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw EndpointBuilderError.invalidObject
        }

        let urlString = try process(urlTemplate: urlTemplate) { param in
            if let paramValue = keyValueParam[param] as? String {
                return try byEncoding(string: paramValue)
            }

            if let paramValue = keyValueParam[param] as? Int {
                return try byEncoding(string: String(paramValue))
            }

            throw EndpointBuilderError.paramMustConvertToString
        }

        guard let url = URL(string: urlString) else {
            throw EndpointBuilderError.invalidUrl
        }

        return url
    }

    public func buildRegex() throws -> String {
        let regexTemplate = urlTemplate.reduce(into: "") { result, character in
            if let scalar = character.unicodeScalars.first,
               EndpointBuilder.regexSpecialCharacters.contains(scalar)
            {
                result.append(EndpointBuilder.regexSkipString)
            }

            result.append(character)
        }

        return try process(urlTemplate: regexTemplate) { _ in
            EndpointBuilder.regexReplacement
        }
    }
}
