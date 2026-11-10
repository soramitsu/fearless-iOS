import Foundation
import IrohaCrypto
import RobinHood

enum PolkaswapAPYServiceError: Swift.Error {
    case unexpectedError
}

protocol PolkaswapAPYService: Actor {
    func getApy(reservesId: String) async throws -> Decimal
}

public actor PolkaswapAPYServiceDefault {
    private let worker: PolkaswapAPYWorker
    private var apyCache: [String: Decimal] = [:]

    public init(worker: PolkaswapAPYWorker) {
        self.worker = worker
    }
}

extension PolkaswapAPYServiceDefault: PolkaswapAPYService {
    func getApy(reservesId: String) async throws -> Decimal {
        if let apy = apyCache[reservesId] {
            return apy
        }

        let apyInfo = try await worker.getAPYInfo()

        for apy in apyInfo {
            apyCache[apy.id] = apy.strategicBonusApy
        }

        if let apy = apyCache[reservesId] {
            return apy
        }

        throw PolkaswapAPYServiceError.unexpectedError
    }
}
