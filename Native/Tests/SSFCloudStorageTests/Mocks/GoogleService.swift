import GoogleAPIClientForREST_Drive
import GoogleAPIClientForRESTCore
import SSFCloudStorage

final class GoogleServiceMock: GoogleService {
    var account: EcryptedBackupAccount?

    // MARK: - executeQuery async

    var executeQueryCallsCount: Int = 0
    var executeQueryCalled: Bool {
        executeQueryCallsCount > 0
    }

    var executeQueryReceivedArguments: GTLRQueryProtocol?
    var executeQueryReceivedInvocations: [GTLRQueryProtocol] = []
    var executeQueryReturnValue: (ticket: GoogleServiceTicket, file: Any?)?
    var executeQueryHandler: ((GTLRQueryProtocol) throws -> (GoogleServiceTicket, Any?)?)?

    func executeQuery(_ queryObj: GTLRQueryProtocol) async throws
        -> (ticket: GoogleServiceTicket, file: Any?)
    {
        executeQueryCallsCount += 1
        executeQueryReceivedArguments = queryObj
        executeQueryReceivedInvocations.append(queryObj)
        if let result = try executeQueryHandler?(queryObj) {
            return result
        }
        return try executeQueryReturnValue ?? createQueryValue(from: queryObj)
    }

    // MARK: - setAuthorizer

    var setAuthorizerCallsCount: Int = 0
    var setAuthorizerCalled: Bool {
        setAuthorizerCallsCount > 0
    }

    var setAuthorizerReceivedArguments: GTMFetcherAuthorizationProtocol?
    var setAuthorizerReceivedInvocations: [GTMFetcherAuthorizationProtocol?] = []

    func set(authorizer: GTMFetcherAuthorizationProtocol?) {
        setAuthorizerCallsCount += 1
        setAuthorizerReceivedArguments = authorizer
        setAuthorizerReceivedInvocations.append(authorizer)
    }
}

extension GoogleServiceMock {
    private func createQueryValue(from query: GTLRQueryProtocol) throws
        -> (GoogleServiceTicket, Any?)
    {
        let ticket = GoogleServiceTicketMock()
        let file = try getFile(from: query)
        return (ticket, file)
    }

    private func getFile(from query: GTLRQueryProtocol) throws -> GTLRObject {
        if query is GTLRDriveQuery_FilesCreate {
            let file = GTLRDrive_File()
            file.identifier = "created-file"
            return file
        } else if query is GTLRDriveQuery_FilesList {
            let fileList = GTLRDrive_FileList()
            let file = GTLRDrive_File()
            file.name = "cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ.json"
            file.identifier = "1"
            file.descriptionProperty = "cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ"
            fileList.files = [file]
            return fileList
        } else {
            let fileData = GTLRDataObject()
            let data = try JSONEncoder().encode(account)
            fileData.data = data
            return fileData
        }
    }
}
