/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Enum is designed to provide definitions
 *  for most common network errors.
 */

public enum NetworkBaseError: Error {
    /// Invalid url provided to request.
    case invalidUrl

    /// Can't serialize request.
    case badSerialization

    /// Can't deserialize response.
    case badDeserialization

    /// Unexpected empty data received in response.
    case unexpectedEmptyData

    /// Unexpected response type received.
    /// For example, http response was expected but another type is received.
    case unexpectedResponseObject
}

/**
 *  Enum is designed to define errors corresponding to http status codes.
 */

public enum NetworkResponseError: Error, Equatable {
    /// Status code 400 - invalid parameters in request.
    case invalidParameters(Data?)

    /// Status code 404 - resource not found.
    case resourceNotFound(Data?)

    /// Status code 401 - can't authorize the request.
    case authorizationError(Data?)

    /// Status code 403 - access is forbidden.
    case accessForbidden(Data?)

    /// Status code 500 - internal server error.
    case internalServerError(Data?)

    /// Unexpected status code.
    case unexpectedStatusCode(Int, Data?)

    static func createFrom(statusCode: Int, data: Data?) -> NetworkResponseError? {
        switch statusCode {
        case 200:
            return nil
        case 400:
            return NetworkResponseError.invalidParameters(data)
        case 401:
            return NetworkResponseError.authorizationError(data)
        case 403:
            return NetworkResponseError.accessForbidden(data)
        case 404:
            return NetworkResponseError.resourceNotFound(data)
        case 500:
            return NetworkResponseError.internalServerError(data)
        default:
            return NetworkResponseError.unexpectedStatusCode(statusCode, data)
        }
    }

    public var withoutData: Self {
        switch self {
        case .invalidParameters: return .invalidParameters(nil)
        case .authorizationError: return .authorizationError(nil)
        case .accessForbidden: return .accessForbidden(nil)
        case .resourceNotFound: return .resourceNotFound(nil)
        case .internalServerError: return .internalServerError(nil)
        case let .unexpectedStatusCode(code, _): return .unexpectedStatusCode(code, nil)
        }
    }
}
