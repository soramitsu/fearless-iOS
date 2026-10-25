/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Subclass of ```BaseOperation``` designed to provide implementation
 *  that requests data from http endpoint.
 *
 *  The client can customize internal network session and provide network
 *  activity indicator manager. Moreover there is an opportunity to
 *  to customize request creation logic and response processing logic.
 */

public final class NetworkOperation<ResultType>: BaseOperation<ResultType> {
    /// Network session to create intenal network data task. By default shared session is used.
    public lazy var networkSession: URLSession = .shared

    /// Network indicator manager to maintain network indicator display.
    /// By default ```NetworkIndicatorManager.shared```.
    public lazy var networkIndicatorManager: NetworkIndicatorManagerProtocol =
        NetworkIndicatorManager.shared

    /// Modifies created request. Pass this object modify requests of the application in a common
    /// way.
    /// For example, provide additional fields in the header or include signature.
    /// Otherwise, consider to create specific custom request in ```NetworkRequestFactoryProtocol```
    /// implementation.
    public var requestModifier: NetworkRequestModifierProtocol?

    /// Creates request to fetch remote data.
    public var requestFactory: NetworkRequestFactoryProtocol

    /// Processes response from remote source.
    public var resultFactory: AnyNetworkResultFactory<ResultType>

    /// Current network executing task.
    private var networkTask: URLSessionDataTask?

    /**
     *  Create network opetation.
     *
     *  - parameters:
     *    - requestFactory: Factory to create fetch requests.
     *    - resultFactory: Factory to process response.
     */

    public init(
        requestFactory: NetworkRequestFactoryProtocol,
        resultFactory: AnyNetworkResultFactory<ResultType>
    ) {
        self.requestFactory = requestFactory
        self.resultFactory = resultFactory

        super.init()
    }

    override public func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            var request = try requestFactory.createRequest()

            if let modifier = requestModifier {
                request = try modifier.modify(request: request)
            }

            let semaphore = DispatchSemaphore(value: 0)

            var receivedData: Data?
            var receivedResponse: URLResponse?
            var receivedError: Error?

            if isCancelled {
                return
            }

            networkIndicatorManager.increment()

            defer {
                networkIndicatorManager.decrement()
            }

            let dataTask = networkSession.dataTask(with: request) { data, response, error in

                receivedData = data
                receivedResponse = response
                receivedError = error

                semaphore.signal()
            }

            networkTask = dataTask
            dataTask.resume()

            _ = semaphore.wait(timeout: .distantFuture)

            if let error = receivedError, NetworkOperationHelper.isCancellation(error: error) {
                return
            }

            result = resultFactory.createResult(
                data: receivedData,
                response: receivedResponse,
                error: receivedError
            )

        } catch {
            result = .failure(error)
        }
    }

    override public func cancel() {
        networkTask?.cancel()

        super.cancel()
    }
}
