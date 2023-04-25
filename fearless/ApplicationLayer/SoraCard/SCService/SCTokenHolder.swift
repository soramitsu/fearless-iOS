import SoraKeystore

final class SCTokenHolder {
    private let eventCenter = EventCenter.shared

    private var token: SCToken = .empty

    static let shared = SCTokenHolder()

    private init() {}

    func set(token: SCToken) {
        if token.isEmpty {
            removeToken()
        }

        guard Date() <= Date(timeIntervalSince1970: TimeInterval(token.accessTokenExpirationTime)) else {
            return
        }
        self.token = token
        eventCenter.notify(with: KYCTokenChanged(token: token))
        eventCenter.notify(with: KYCUserStatusChanged())
    }

    func removeToken() {
        token = .empty
        eventCenter.notify(with: KYCTokenChanged(token: .empty))
        eventCenter.notify(with: KYCUserStatusChanged())
    }
}

struct SCToken: Codable, SecretDataRepresentable {
    static let empty: SCToken = .init(refreshToken: "", accessToken: "", accessTokenExpirationTime: 0)

    let refreshToken: String
    let accessToken: String
    let accessTokenExpirationTime: Int64

    var isEmpty: Bool {
        refreshToken == "" && accessToken == "" && accessTokenExpirationTime == 0
    }

    init(refreshToken: String, accessToken: String, accessTokenExpirationTime: Int64) {
        self.refreshToken = refreshToken
        self.accessToken = accessToken
        self.accessTokenExpirationTime = accessTokenExpirationTime
    }

    init?(secretData: SecretDataRepresentable?) {
        guard let secretUTF8String = secretData?.toUTF8String() else { return nil }
        let secretPrts = secretUTF8String.split(separator: "@").map { String($0) }
        guard secretPrts.count == 3 else { return nil }

        refreshToken = secretPrts[0]
        accessToken = secretPrts[1]
        accessTokenExpirationTime = Int64(secretPrts[2]) ?? 0
    }

    func asSecretData() -> Data? {
        "\(refreshToken)@\(accessToken)@\(accessTokenExpirationTime)".data(using: .utf8)
    }
}
