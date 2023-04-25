import Foundation

extension SCKYCService {
    func userStatus() async -> SCKYCUserStatus? {
        guard case let .success(statuses) = await kycStatuses(),
              let userStatus = statuses.sorted.last?.userStatus
        else { return nil }
        return userStatus
    }

    func kycStatuses() async -> Result<[SCKYCStatusResponse], NetworkingError> {
        try? await refreshAccessTokenIfNeeded()
        let request = APIRequest(method: .get, endpoint: SCEndpoint.kycStatuses)
        let response: Result<[SCKYCStatusResponse], NetworkingError> = await client.performDecodable(request: request)
        if case let .success(statuses) = response, let userStatus = statuses.sorted.last?.userStatus {
            self.userStatusYield?(userStatus)
        }
        return response
    }

    func kycAttempts() async -> Result<SCKYCAtempts, NetworkingError> {
        try? await refreshAccessTokenIfNeeded()
        let request = APIRequest(method: .get, endpoint: SCEndpoint.kycAttemptCount)
        return await client.performDecodable(request: request)
    }
}

extension Array where Element == SCKYCStatusResponse {
    var sorted: [Element] {
        self.sorted(by: { sr1, sr2 in
            sort(sr1: sr1, sr2: sr2)
        })
    }

    func sort(
        sr1: SCKYCStatusResponse,
        sr2: SCKYCStatusResponse
    ) -> Bool {
        (
            sr1.userStatus.priority,
            sr1.updateTime
        ) < (
            sr2.userStatus.priority,
            sr2.updateTime
        )
    }
}

struct SCKYCStatusResponse: Codable {
    let kycId: String
    let personId: String
    let userReferenceNumber: String
    let referenceId: String
    private let kycStatus: SCKYCStatus
    private let verificationStatus: SCVerificationStatus
    let ibanStatus: SCIbanStatus
    let additionalDescription: String?
    let updateTime: Int64

    enum CodingKeys: String, CodingKey {
        case kycId = "kyc_id"
        case personId = "person_id"
        case userReferenceNumber = "user_reference_number"
        case referenceId = "reference_id"
        case kycStatus = "kyc_status"
        case verificationStatus = "verification_status"
        case ibanStatus = "iban_status"
        case additionalDescription = "additional_description"
        case updateTime = "update_time"
    }

    var userStatus: SCKYCUserStatus {
        if kycStatus == .completed && verificationStatus == .pending {
            return .pending
        }

        if kycStatus == .failed || kycStatus == .rejected || verificationStatus == .rejected {
            return .rejected
        }

        if kycStatus == .failed {
            return .userCanceled
        }

        if verificationStatus == .accepted {
            return .successful
        }

        return .notStarted
    }
}

enum SCKYCUserStatus {
    case notStarted
    case pending
    case rejected
    case successful
    case userCanceled

    var priority: Int {
        switch self {
        case .notStarted, .userCanceled:
            return 0
        case .pending:
            return 1
        case .successful, .rejected:
            return 2
        }
    }

    func title(for locale: Locale) -> String {
        switch self {
        case .notStarted, .userCanceled:
            return R.string.localizable.soraCardStateNoneTitle(preferredLanguages: locale.rLanguages)
        case .pending:
            return R.string.localizable.soraCardStateVerificationTitle(preferredLanguages: locale.rLanguages)
        case .rejected:
            return R.string.localizable.soraCardStateRejectedTitle(preferredLanguages: locale.rLanguages)
        case .successful:
            return R.string.localizable.soraCardStateOnwayTitle(preferredLanguages: locale.rLanguages)
        }
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

struct SCKYCAtempts: Codable {
    let total: Int64
    let completed: Int64
    let rejected: Int64
    let hasFreeAttempts: Bool

    enum CodingKeys: String, CodingKey {
        case total
        case completed
        case rejected
        case hasFreeAttempts = "free_attempt"
    }
}
