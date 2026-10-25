import GoogleAPIClientForREST_Drive
import GoogleAPIClientForRESTCore

public protocol GoogleService {
    func executeQuery(_ queryObj: GTLRQueryProtocol) async throws
        -> (ticket: GoogleServiceTicket, file: Any?)
    func set(authorizer: GTMFetcherAuthorizationProtocol?)
}

public class BaseGoogleService: GoogleService {
    private let googleService: GTLRDriveService

    public init(googleService: GTLRDriveService) {
        self.googleService = googleService
    }

    public func executeQuery(_ queryObj: GTLRQueryProtocol) async throws
        -> (ticket: GoogleServiceTicket, file: Any?)
    {
        try await withCheckedThrowingContinuation { continuation in
            googleService.executeQuery(queryObj) { gtlrTicket, file, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let ticket = BaseGoogleServiceTicket(ticket: gtlrTicket)
                continuation.resume(returning: (ticket, file))
            }
        }
    }

    public func set(authorizer: GTMFetcherAuthorizationProtocol?) {
        googleService.authorizer = authorizer
    }
}
