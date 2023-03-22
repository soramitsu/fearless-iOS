extension SCKYCService {
    func xOneStatus(paymentId: String) async -> Result<SCKYCStatusResponse, NetworkingError> {
        let request = APIRequest(method: .get, endpoint: SCEndpoint.xOneStatus(paymentId: paymentId))
        return await client.performDecodable(request: request)
    }
}
