import Foundation
import FireMock
@testable import fearless

enum TypeDefFileMock: FireMockProtocol {
    case westendDefault
    case kusamaDefault
    case polkadotDefault
    case westendNetwork
    case kusamaNetwork
    case polkadotNetwork

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .westendDefault, .kusamaDefault, .polkadotDefault:
            return R.file.runtimeDefaultJson.fullName
        case .westendNetwork:
            return R.file.runtimeWestendJson.fullName
        case .kusamaNetwork:
            return R.file.runtimeKusamaJson.fullName
        case .polkadotNetwork:
            return R.file.runtimeKusamaJson.fullName
        }
    }
}

extension TypeDefFileMock {
    static func register(mock: TypeDefFileMock, url: URL) {
        FireMock.register(mock: mock, forURL: url, httpMethod: .get)
    }
}
