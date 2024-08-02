import RobinHood
import SSFModels

enum AddressValidationResult {
    case valid(String)
    case sameAddress(String)
    case invalid(String?)

    var isValid: Bool {
        switch self {
        case .valid:
            return true
        default:
            return false
        }
    }

    var isValidOrSame: Bool {
        switch self {
        case .valid, .sameAddress:
            return true
        default:
            return false
        }
    }
}

protocol AddressChainDefinerProtocol {
    func getPossibleChains(for address: String) async -> [ChainModel]?
    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult
}

final class AddressChainDefiner {
    private let operationManager: OperationManagerProtocol
    private let chainModelRepository: AnyDataProviderRepository<ChainModel>
    private let wallet: MetaAccountModel

    init(
        operationManager: OperationManagerProtocol,
        chainModelRepository: AnyDataProviderRepository<ChainModel>,
        wallet: MetaAccountModel
    ) {
        self.operationManager = operationManager
        self.chainModelRepository = chainModelRepository
        self.wallet = wallet
    }

    func getPossibleChains(for address: String) async -> [ChainModel]? {
        let fetchOperation = chainModelRepository.fetchAllOperation(with: RepositoryFetchOptions())
        operationManager.enqueue(operations: [fetchOperation], in: .transient)

        return await withCheckedContinuation { continuation in
            fetchOperation.completionBlock = {
                let chains = try? fetchOperation.extractNoCancellableResultData()
                let posssibleChains = chains?.filter { [weak self, address] chain in
                    guard let strongSelf = self else { return false }
                    guard strongSelf.chainIsEnabled(chain: chain) else {
                        return false
                    }
                    return strongSelf.validate(address: address, for: chain).isValidOrSame
                }
                continuation.resume(returning: posssibleChains)
            }
        }
    }

    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult {
        guard let address = address, address.isNotEmpty, let accoundId = (try? AddressFactory.accountId(from: address, chain: chain)) else {
            return .invalid(address)
        }
        if accoundId == wallet.substrateAccountId || accoundId == wallet.ethereumAddress {
            return .sameAddress(address)
        }
        return .valid(address)
    }

    private func chainIsEnabled(chain: ChainModel) -> Bool {
        let chainAssets = chain.chainAssets
        let enabledAssetIds: [String] = wallet.assetsVisibility
            .filter { !$0.hidden }
            .map { $0.assetId }
        let enabled = chainAssets.filter {
            enabledAssetIds.contains($0.identifier)
        }
        return enabled.isNotEmpty
    }
}
