import Foundation

protocol NetworkClient {
    func perform(request: URLRequest) async -> Result<Data, NetworkingError>
}
