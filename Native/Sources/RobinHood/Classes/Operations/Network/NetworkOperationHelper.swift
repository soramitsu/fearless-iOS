/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Class is designed to provide helper methods
 *  to network operation.
 */

public enum NetworkOperationHelper {
    /**
     *  Checks whether the error is actually cancellation of the request.
     *
     *  - parameters:
     *    - error: An error to check for cancellation.
     *  - returns: ```true``` if error is cancellation otherwise - ```false```.
     */

    public static func isCancellation(error: Error) -> Bool {
        if let nserror = error as NSError?, nserror.code == NSURLErrorCancelled {
            return true
        } else {
            return false
        }
    }

    /**
     *  Creates an error based on response's http status code.
     *
     *  - parameters:
     *    - response: Http response to process.
     *  - returns: Error if http response contains erroneous status code,
     *  otherwise - ```nil```.
     */

    public static func createError(from response: URLResponse?, data: Data?) -> Error? {
        guard let httpUrlResponse = response as? HTTPURLResponse else {
            return NetworkBaseError.unexpectedResponseObject
        }

        return NetworkResponseError.createFrom(statusCode: httpUrlResponse.statusCode, data: data)
    }
}
