import Foundation

 extension SCKYCService {
     func kycStatus() async -> Result<[SCKYCStatusResponse], NetworkingError> {
         let request = APIRequest(method: .get, endpoint: SCEndpoint.kycStatus)
         return await client.performDecodable(request: request)
     }
 }

 struct SCKYCStatusResponse: Codable {
     let kycId: String
     let personId: String
     let userReferenceNumber: String
     let referenceId: String
     let kycStatus: SCKYCStatus
     let verificationStatus: SCVerificationStatus
     let ibanStatus: SCIbanStatus
     let additionalDescription: String?

     enum CodingKeys: String, CodingKey {
         case kycId = "kyc_id"
         case personId = "person_id"
         case userReferenceNumber = "user_reference_number"
         case referenceId = "reference_id"
         case kycStatus = "kyc_status"
         case verificationStatus = "verification_status"
         case ibanStatus = "iban_status"
         case additionalDescription = "additional_description"
     }
 }

 enum SCKYCStatus: String, Codable {
     case started = "Started"
     case completed = "Completed"
     case successful = "Successful"
     case failed = "Failed"
     case rejected = "Rejected"
 }

 enum SCVerificationStatus: String, Codable {
     case none = "None"
     case pending = "Pending"
     case accepted = "Accepted"
     case rejected = "Rejected"
 }

 enum SCIbanStatus: String, Codable {
     case none = "None"
     case pending = "Pending"
     case rejected = "Rejected"
 }
