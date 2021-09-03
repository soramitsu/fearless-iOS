import Foundation
import FireMock

enum TotalRewardMock: FireMockProtocol {
    case westend
    case error

    var bundle: Bundle { Bundle(for: NetworkBaseTests.self) }

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .westend:
            return "rewardResponse.json"
        case .error:
            return "rewardErrorResponse.json"
        }
    }
}

extension TotalRewardMock {
    static func register(mock: TotalRewardMock, url: URL) {
        FireMock.register(mock: mock, forURL: url, httpMethod: .post)
    }
}
