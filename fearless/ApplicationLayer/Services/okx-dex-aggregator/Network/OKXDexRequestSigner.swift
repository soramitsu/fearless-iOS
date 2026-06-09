import Foundation
import CryptoKit
import SSFNetwork

// https://www.okx.com/ru/web3/build/docs/waas/rest-authentication

protocol OKXDexRequestSigningCredentialsSource {
    var okxApiKey: String { get }
    var okxSecretKey: String { get }
    var okxPassphrase: String { get }
    var okxProjectId: String { get }
}

struct OKXDexEnvironmentCredentialsSource: OKXDexRequestSigningCredentialsSource {
    var okxApiKey: String { OKXApiKeys.okxApiKey }
    var okxSecretKey: String { OKXApiKeys.okxSecretKey }
    var okxPassphrase: String { OKXApiKeys.okxPassphrase }
    var okxProjectId: String { OKXApiKeys.okxProjectId }
}

enum OKXDexRequestSignerError: Error {
    case accountUnavailable
    case invalidData
    case invalidSecret
}

final class OKXDexRequestSigner: RequestSigner {
    private let credentialsSource: OKXDexRequestSigningCredentialsSource
    private let dateProvider: () -> Date

    init(
        credentialsSource: OKXDexRequestSigningCredentialsSource = OKXDexEnvironmentCredentialsSource(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.credentialsSource = credentialsSource
        self.dateProvider = dateProvider
    }

    func sign(request: inout URLRequest, config: RequestConfig) throws {
        let timestamp = DateFormatter.iso.string(from: dateProvider())
        request.setValue(timestamp, forHTTPHeaderField: "OK-ACCESS-TIMESTAMP")

        let apiKey = credentialsSource.okxApiKey
        request.setValue(apiKey, forHTTPHeaderField: "OK-ACCESS-KEY")

        let secretKey = credentialsSource.okxSecretKey

        let passphrase = credentialsSource.okxPassphrase
        request.setValue(passphrase, forHTTPHeaderField: "OK-ACCESS-PASSPHRASE")

        let projectId = credentialsSource.okxProjectId
        request.setValue(projectId, forHTTPHeaderField: "OK-ACCESS-PROJECT")

        let endpoint = request.url?.absoluteString.replacingOccurrences(
            of: config.baseURL.absoluteString,
            with: "",
            options: .caseInsensitive,
            range: nil
        )
        let body = config.body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let signingPayload = [timestamp, config.method.rawValue.uppercased(), endpoint ?? "", body].joined()
        guard let sign = signingPayload.data(using: .utf8) else {
            throw OKXDexRequestSignerError.invalidData
        }
        let key = SymmetricKey(data: Data(secretKey.utf8))

        let signature = HMAC<SHA256>.authenticationCode(for: sign, using: key)
        let signatureData = Data(signature)
        request.setValue(signatureData.base64EncodedString(), forHTTPHeaderField: "OK-ACCESS-SIGN")
    }
}
