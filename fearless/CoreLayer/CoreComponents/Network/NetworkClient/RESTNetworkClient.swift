import Foundation

final class RESTNetworkClient {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    private func processDataResponse(
        urlRequest _: URLRequest,
        data: Data,
        response: URLResponse
    ) -> Result<Data, NetworkingError> {
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            return .failure(.init(status: .unknown))
        }
        guard 200 ..< 299 ~= statusCode else {
            return .failure(.init(errorCode: statusCode))
        }

        return .success(data)
    }
}

extension RESTNetworkClient: NetworkClient {
    func perform(request: URLRequest) async -> Result<Data, NetworkingError> {
        var data: Data, response: URLResponse

        do {
            (data, response) = try await withCheckedThrowingContinuation { continuation in
                session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let response = response, let data = data {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: NetworkingError(status: .unknown))
                    }
                }
                .resume()
            }
        } catch let error as NSError {
            return .failure(.init(errorCode: error.code))
        }

        return processDataResponse(urlRequest: request, data: data, response: response)
    }
}
