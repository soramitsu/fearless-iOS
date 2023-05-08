import Foundation

public struct NetworkingError: Error, LocalizedError {
    public enum Status: Int {
        case unknown = -1
        case networkUnreachable = 0

        case unableToParseResponse = 1
        case unableToParseRequest = 2

        // 1xx Informational
        case continueError = 100
        case switchingProtocols = 101
        case processing = 102

        // 2xx Success
        case ok = 200
        case created = 201
        case accepted = 202
        case nonAuthoritativeInformation = 203
        case noContent = 204
        case resetContent = 205
        case partialContent = 206
        case multiStatus = 207
        case alreadyReported = 208
        case IMUsed = 226

        // 3xx Redirection
        case multipleChoices = 300
        case movedPermanently = 301
        case found = 302
        case seeOther = 303
        case notModified = 304
        case useProxy = 305
        case switchProxy = 306
        case temporaryRedirect = 307
        case permenantRedirect = 308

        // 4xx Client Error
        case badRequest = 400
        case unauthorized = 401
        case paymentRequired = 402
        case forbidden = 403
        case notFound = 404
        case methodNotAllowed = 405
        case notAcceptable = 406
        case proxyAuthenticationRequired = 407
        case requestTimeout = 408
        case conflict = 409
        case gone = 410
        case lengthRequired = 411
        case preconditionFailed = 412
        case payloadTooLarge = 413
        case uriTooLong = 414
        case unsupportedMediaType = 415
        case rangeNotSatisfiable = 416
        case expectationFailed = 417
        case teapot = 418
        case misdirectedRequest = 421
        case unprocessableEntity = 422
        case locked = 423
        case failedDependency = 424
        case upgradeRequired = 426
        case preconditionRequired = 428
        case tooManyRequests = 429
        case requestHeaderFieldsTooLarge = 431
        case unavailableForLegalReasons = 451

        // 4xx nginx
        case noResponse = 444
        case sslCertificateError = 495
        case sslCertificateRequired = 496
        case httpRequestSentToHTTPSPort = 497
        case clientClosedRequest = 499

        // 5xx Server Error
        case internalServerError = 500
        case notImplemented = 501
        case badGateway = 502
        case serviceUnavailable = 503
        case gatewayTimeout = 504
        case httpVersionNotSupported = 505
        case variantAlsoNegotiates = 506
        case insufficientStorage = 507
        case loopDetected = 508
        case notExtended = 510
        case networkAuthenticationRequired = 511

        // domain
        case cancelled = -999
        case badURL = -1000
        case timedOut = -1001
        case unsupportedURL = -1002
        case cannotFindHost = -1003
        case cannotConnectToHost = -1004
        case networkConnectionLost = -1005
        case dnsLookupFailed = -1006
        case httpTooManyRedirects = -1007
        case resourceUnavailable = -1008
        case notConnectedToInternet = -1009
        case redirectToNonExistentLocation = -1010
        case badServerResponse = -1011
        case userCancelledAuthentication = -1012
        case userAuthenticationRequired = -1013
        case zeroByteResource = -1014
        case cannotDecodeRawData = -1015
        case cannotDecodeContentData = -1016
        case cannotParseResponse = -1017
        case appTransportSecurityRequiresSecureConnection = -1022
        case fileDoesNotExist = -1100
        case fileIsDirectory = -1101
        case noPermissionsToReadFile = -1102
        case dataLengthExceedsMaximum = -1103

        // SSL errors
        case secureConnectionFailed = -1200
        case serverCertificateHasBadDate = -1201
        case serverCertificateUntrusted = -1202
        case serverCertificateHasUnknownRoot = -1203
        case serverCertificateNotYetValid = -1204
        case clientCertificateRejected = -1205
        case cclientCertificateRequired = -1206

        case cannotLoadFromNetwork = -2000

        // Download and file I/O errors
        case cannotCreateFile = -3000
        case cannotOpenFile = -3001
        case cannotCloseFile = -3002
        case cannotWriteToFile = -3003
        case ccannotRemoveFile = -3004
        case cannotMoveFile = -3005
        case downloadDecodingFailedMidStream = -3006
        case downloadDecodingFailedToComplete = -3007
    }

    public var status: Status
    public var code: Int { status.rawValue }
    public var jsonPayload: Any?

    public init(errorCode: Int) {
        status = Status(rawValue: errorCode) ?? .unknown
    }

    public init(status: Status) {
        self.status = status
    }

    public init(error: Error) {
        if let networkingError = error as? NetworkingError {
            status = networkingError.status
            jsonPayload = networkingError.jsonPayload
        } else {
            if let theError = error as? URLError {
                status = Status(rawValue: theError.errorCode) ?? .unknown
            } else {
                status = .unknown
            }
        }
    }

    // for LocalizedError protocol
    public var errorDescription: String? {
        "\(status)"
    }
}

extension NetworkingError: CustomStringConvertible {
    public var description: String {
        String(describing: status)
            .replacingOccurrences(
                of: "(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])",
                with: " ",
                options: [.regularExpression]
            )
            .capitalized
    }
}

public extension NetworkingError {
    static var unableToParseResponse: NetworkingError {
        NetworkingError(status: .unableToParseResponse)
    }

    static var unableToParseRequest: NetworkingError {
        NetworkingError(status: .unableToParseRequest)
    }

    static var unknownError: NetworkingError {
        NetworkingError(status: .unknown)
    }

    static var unauthorized: NetworkingError {
        NetworkingError(status: .unauthorized)
    }
}

public extension DecodingError {
    var description: String? {
        switch self {
        case let .typeMismatch(_, value):
            return "typeMismatch error: \(value.debugDescription)  \(localizedDescription)"
        case let .valueNotFound(_, value):
            return "valueNotFound error: \(value.debugDescription)  \(localizedDescription)"
        case let .keyNotFound(_, value):
            return "keyNotFound error: \(value.debugDescription)  \(localizedDescription)"
        case let .dataCorrupted(key):
            return "dataCorrupted error at: \(key)  \(localizedDescription)"
        default:
            return "decoding error: \(localizedDescription)"
        }
    }
}
