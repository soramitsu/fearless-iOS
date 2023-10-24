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

    var chains: [ChainModel]?

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
                    return strongSelf.validate(address: address, for: chain).isValidOrSame
                }
                continuation.resume(returning: posssibleChains)
            }
        }
    }

    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult {
        guard let address = address, let accoundId = (try? AddressFactory.accountId(from: address, chain: chain)) else {
            return .invalid(address)
        }
        if accoundId == wallet.substrateAccountId || accoundId == wallet.ethereumAddress {
            return .sameAddress(address)
        }
        return .valid(address)
    }
}
