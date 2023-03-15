import Foundation

 enum HTTPMethod: String {
     case get = "GET"
     case post = "POST"
 }

 struct HTTPHeader {
     let field: String
     let value: String
 }

 protocol Endpoint {
     var path: String { get }
 }

 final class APIRequest {
     let method: HTTPMethod
     let endpoint: Endpoint
     var queryItems: [URLQueryItem]?
     var headers: [HTTPHeader]?
     var body: Data?

     init(method: HTTPMethod, endpoint: Endpoint) {
         self.method = method
         self.endpoint = endpoint
     }

     init(
         method: HTTPMethod,
         endpoint: Endpoint,
         body: Data
     ) {
         self.method = method
         self.endpoint = endpoint
         self.body = body
     }
 }

 public class SCAPIClient {
     static let shared = SCAPIClient(
         // TODO: SC credentials
         baseURL: URL(string: "https://sora-card.sc1.dev.sora2.soramitsu.co.jp/")!,
         baseAuth: "",
         accessToken: SCStorage.shared.accessToken() ?? "",
         refreshToken: SCStorage.shared.refreshToken() ?? "",
         logLevels: .debug
     )

     init(
         baseURL: URL,
         baseAuth: String,
         accessToken: String,
         refreshToken: String,
         logLevels: NetworkingLogLevel = .debug
     ) {
         self.baseURL = baseURL
         self.baseAuth = baseAuth
         self.accessToken = accessToken
         self.refreshToken = refreshToken
         logger.logLevels = logLevels
     }

     private let apiKey = ""
     private let baseAuth: String
     private(set) var accessToken: String
     private var refreshToken: String
     private let baseURL: URL

     private let session = URLSession.shared
     private let logger = NetworkingLogger()

     private let jsonDecoder: JSONDecoder = {
         let jsonDecoder = JSONDecoder()
         let dateFormatter = DateFormatter()
         dateFormatter.dateFormat = "yyyy-mm-dd"
         jsonDecoder.dateDecodingStrategy = .formatted(dateFormatter)
         return jsonDecoder
     }()

     func set(accessToken: String, refreshToken: String) {
         self.accessToken = accessToken
         self.refreshToken = refreshToken
     }

     func set(accessToken: String) {
         self.accessToken = accessToken
     }

     func performDecodable<T: Decodable>(request: APIRequest) async -> Result<T, NetworkingError> {
         let result = await perform(request: request)

         switch result {
         case let .success(data):
             do {
                 let decodedData = try jsonDecoder.decode(T.self, from: data)
                 return .success(decodedData)
             } catch {
                 print(error)
                 return .failure(.init(status: .cannotDecodeRawData))
             }
         case let .failure(error):
             return .failure(error)
         }
     }

     func perform(request: APIRequest) async -> Result<Data, NetworkingError> {
         var urlComponents = URLComponents()
         urlComponents.scheme = baseURL.scheme
         urlComponents.host = baseURL.host
         urlComponents.port = baseURL.port
         urlComponents.path = baseURL.path
         if !apiKey.isEmpty {
             urlComponents.queryItems = (request.queryItems ?? []) + [URLQueryItem(name: "api_key", value: apiKey)]
         } else {
             urlComponents.queryItems = request.queryItems
         }

         guard let url = urlComponents.url?.appendingPathComponent(request.endpoint.path) else {
             return .failure(.init(status: .badURL))
         }

         var urlRequest = URLRequest(url: url)
         urlRequest.httpMethod = request.method.rawValue
         urlRequest.httpBody = request.body

         urlRequest.addValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")

         request.headers?.forEach {
             urlRequest.addValue($0.value, forHTTPHeaderField: $0.field)
         }

         logger.log(request: urlRequest)

         var data: Data, response: URLResponse
         do {
             (data, response) = try await withCheckedThrowingContinuation { continuation in
                 session.dataTask(with: urlRequest) { data, response, error in
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

         return processDataResponse(request: request, urlRequest: urlRequest, data: data, response: response)
     }

     func processDataResponse(
         request _: APIRequest,
         urlRequest _: URLRequest,
         data: Data,
         response: URLResponse
     ) -> Result<Data, NetworkingError> {
         logger.log(response: response, data: data)

         guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
             return .failure(.init(status: .unknown))
         }
         guard 200 ..< 299 ~= statusCode else {
             return .failure(.init(errorCode: statusCode))
         }

         return .success(data)
     }
 }
