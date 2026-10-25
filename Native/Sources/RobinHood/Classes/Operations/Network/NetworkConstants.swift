/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Enum is designed to provide definitions for
 *  http methods.
 */

public enum HttpMethod: String {
    /// Form GET request
    case get

    /// Form POST request
    case post

    /// Form PUT request
    case put

    /// Form DELETE request
    case delete
}

/**
 *  Enum is designed to provide definitions for
 *  commonly used http methods.
 */

public enum HttpContentType: String {
    /// application/json type. Request's body contains json.
    case json = "application/json"
}

/**
 *  Enum is designed to provide definitions for
 * commonly used http header keys.
 */

public enum HttpHeaderKey: String {
    /// 'Content-Type:' key.
    case contentType = "Content-Type"

    /// 'Authorization:' key
    case authorization = "Authorization"
}
