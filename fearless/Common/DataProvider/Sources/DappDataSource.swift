import Foundation
import RobinHood

struct DappCategory: Codable, Equatable {
    let type: DappCategoryType
    let apps: [TonDapp]
}

enum DappCategoryType: String, Codable, Equatable {
    case top
    case connected
    case featured
    case utilities
    case nft
    case defi
}

final class DappDataSource: SingleValueProviderSourceProtocol {
    static let fetchLocalData = true
    typealias Model = [DappCategory]
    
    func fetchOperation() -> CompoundOperationWrapper<[DappCategory]?> {
        if Self.fetchLocalData {
            return localOperation()
        } else {
            return remoteOperation()
        }
    }
    
    // MARK: - Private methods
    
    private func remoteOperation() -> CompoundOperationWrapper<[DappCategory]?> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: ApplicationConfig.shared.dappSourceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }
        
        let resultFactory = AnyNetworkResultFactory<[DappCategory]?> { data, response, error in
            do {
                if let data = data {
                    let response = try JSONDecoder().decode(
                        [DappCategory].self,
                        from: data
                    )
                    
                    return .success(response)
                } else if let error = error {
                    return .failure(error)
                } else {
                    return .failure(ConvenienceError(error: "wrong data"))
                }
            } catch {
                return .failure(error)
            }
        }
        
        let operation = NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: resultFactory
        )
        
        return CompoundOperationWrapper(
            targetOperation: operation,
            dependencies: operation.dependencies
        )
    }
    
    private func localOperation() -> CompoundOperationWrapper<[DappCategory]?> {
        let target = ClosureOperation {
            guard let chainsUrl = Bundle.main.url(forResource: "dapps", withExtension: "json") else {
                throw ChainSyncServiceError.missingLocalFile
            }
            
            let data = try Data(contentsOf: chainsUrl)
            let dapps = try JSONDecoder().decode([DappCategory]?.self, from: data)
            return dapps
        }
        return CompoundOperationWrapper(
            targetOperation: target,
            dependencies: []
        )
    }
}
