import Foundation

/// Separate opt-in bound for FPBKGEN1; the legacy challenge/envelope transport remains capped at 256 KiB.
final class URLSessionPasskeyGenerationTransport: PasskeyBackupHTTPTransport {
    private let session: URLSession
    private let delegate: PasskeyBackupGenerationSessionDelegate

    init(configuration: URLSessionConfiguration? = nil) {
        let configuration = configuration?.copy() as? URLSessionConfiguration ?? .ephemeral
        configuration.timeoutIntervalForRequest = PasskeyBackupHTTPTransportPolicy.requestTimeout
        configuration.timeoutIntervalForResource = PasskeyBackupHTTPTransportPolicy.resourceTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        delegate = PasskeyBackupGenerationSessionDelegate()
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    var inFlightRequestCount: Int { delegate.bounded.inFlightRequestCount }

    func execute(_ request: PasskeyBackupHTTPRequest) async throws -> PasskeyBackupHTTPResponse {
        guard request.url.scheme == "https", request.url.host == "www.googleapis.com",
              request.url.user == nil, request.url.password == nil,
              request.url.port == nil || request.url.port == 443,
              ["GET", "POST"].contains(request.method),
              (request.method == "POST") == (request.body != nil) else {
            throw GoogleDrivePasskeyBackupError.malformedResponse
        }
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        request.headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let body = request.body {
            // Foundation requests a fresh stream if authentication/retry needs another body.
            // The delegate always refuses it; never give URLSession a replayable Data body.
            urlRequest.httpBodyStream = InputStream(data: body)
            urlRequest.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
        }
        let (data, response) = try await delegate.bounded.data(for: urlRequest, session: session)
        guard let response = response as? HTTPURLResponse else {
            throw GoogleDrivePasskeyBackupError.malformedResponse
        }
        return PasskeyBackupHTTPResponse(statusCode: response.statusCode, body: data)
    }
}

/// Delegate callbacks retain the bounded transport's cancellation/exactly-once completion behavior.
final class PasskeyBackupGenerationSessionDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    let bounded = PasskeyBackupBoundedSessionDelegate(
        maximumResponseBytes: PasskeyBackupGenerationV1Format.maximumBytes
    )

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        bounded.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        bounded.urlSession(session, dataTask: dataTask, didReceive: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        bounded.urlSession(session, task: task, didCompleteWithError: error)
    }

    func urlSession(
        _: URLSession, task _: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
    ) { completionHandler(nil) }

    func urlSession(
        _: URLSession, task _: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void
    ) { completionHandler(nil) }

    @available(iOS 17.0, *)
    func urlSession(
        _: URLSession, task _: URLSessionTask, needNewBodyStreamFrom _: Int64,
        completionHandler: @escaping (InputStream?) -> Void
    ) { completionHandler(nil) }

    func urlSession(
        _: URLSession, task _: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Bearer authentication is supplied explicitly. Never use ambient credentials or resubmit a body for auth.
        completionHandler(
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
                ? .performDefaultHandling : .cancelAuthenticationChallenge,
            nil
        )
    }
}
