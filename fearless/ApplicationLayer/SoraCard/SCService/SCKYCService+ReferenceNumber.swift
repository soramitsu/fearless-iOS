import Foundation

extension SCKYCService {
    func referenceNumber(
        phone: String,
        email: String
    ) async -> Result<SCReferenceNumberResponse, NetworkingError> {
        let parameters = """
        {
            "MobileNumber": "\(phone)",
            "Email": "\(email)",
            "AddressChanged": false,
            "DocumentChanged": false,
            "AdditionalData": ""
        }
        """
        let postData = parameters.data(using: .utf8) ?? Data()
        let request = APIRequest(method: .post, endpoint: SCEndpoint.getReferenceNumber, body: postData)
        request.headers = [.init(field: "Content-Type", value: "application/json")]
        return await client.performDecodable(request: request)
    }
}

struct SCReferenceNumberResponse: Codable {
    let statusCode: Int
    let statusDescription: String
    let referenceNumber: String
    let referenceID: String
    let callerReferenceID: String

    enum CodingKeys: String, CodingKey {
        case statusCode = "StatusCode"
        case statusDescription = "StatusDescription"
        case referenceNumber = "ReferenceNumber"
        case referenceID = "ReferenceID"
        case callerReferenceID = "CallerReferenceID"
    }
}
