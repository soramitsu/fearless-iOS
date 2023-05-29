import Foundation

final class NetworkWorker {
    func performRequest<T>(with config: RequestConfig) async throws -> T {
        let requestConfigurator = try BaseRequestConfiguratorFactory().buildRequestConfigurator(with: config.requestType, baseURL: config.baseURL)
        let requestSigner = try BaseRequestSignerFactory().buildRequestSigner(with: config.signingType)
        let networkClient = BaseNetworkClientFactory().buildNetworkClient(with: config.networkClientType)
        let responseDecoder = BaseResponseDecoderFactory().buildResponseDecoder(with: config.decoderType)

        var request = try requestConfigurator.buildRequest(with: config)
        requestSigner?.sign(request: &request, config: config)
        let response = await networkClient.perform(request: request)

        switch response {
        case let .success(response):
            let decoded: T = try responseDecoder.decode(data: response)
            return decoded
        case let .failure(error):
            throw error
        }
    }
}
