// import Foundation
// import StreamURLSessionTransport
// import OpenAPIRuntime
// import HTTPTypes
// import TonAPI
//
// final class TonAPIAssembly {
//    let tonAPIURL: URL
//
//    init(tonAPIURL: URL) {
//        self.tonAPIURL = tonAPIURL
//    }
//
//    private var _tonAPIClient: TonAPI.Client?
//    func tonAPIClient() -> TonAPI.Client {
//        if let tonAPIClient = _tonAPIClient {
//            return tonAPIClient
//        }
//        let tonAPIClient = TonAPI.Client(
//            serverURL: tonAPIURL,
//            transport: transport,
//            middlewares: []
//        )
//        _tonAPIClient = tonAPIClient
//        return tonAPIClient
//    }
//
//    // MARK: - Private
//
//    private lazy var transport: StreamURLSessionTransport = {
//        StreamURLSessionTransport(urlSessionConfiguration: urlSessionConfiguration)
//    }()
//
//    private var urlSessionConfiguration: URLSessionConfiguration {
//        let configuration = URLSessionConfiguration.default
//        configuration.timeoutIntervalForRequest = 60
//        configuration.timeoutIntervalForResource = 60
//        return configuration
//    }
// }
