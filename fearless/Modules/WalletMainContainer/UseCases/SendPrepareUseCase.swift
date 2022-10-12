import RobinHood

protocol SendPrepareUseCaseDelegate: NSObject {
    func didReceive(possibleChains: [ChainModel])
    func didReceive(chainAsset: ChainAsset, address: String)
}

final class SendPrepareUseCase {
    private let chainModelRepository: AnyDataProviderRepository<ChainModel>
    private let operationQueue = OperationQueue()
    private var address: String?
    private weak var delegate: SendPrepareUseCaseDelegate?

    init(
        chainModelRepository: AnyDataProviderRepository<ChainModel>
    ) {
        self.chainModelRepository = chainModelRepository
    }

    func getPossibleChains(for address: String, delegate: SendPrepareUseCaseDelegate) {
        let fetchOperation = chainModelRepository.fetchAllOperation(with: RepositoryFetchOptions())
        self.address = address
        self.delegate = delegate

        fetchOperation.completionBlock = {
            let chains = try? fetchOperation.extractNoCancellableResultData()
            let posssibleChains = chains?.filter { [weak self] chain in
                guard let strongSelf = self else { return false }
                return strongSelf.validate(address: address, for: chain)
            }
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.didReceive(possibleChains: posssibleChains ?? [])
            }
        }
        operationQueue.addOperation(fetchOperation)
    }

    private func validate(address: String, for chain: ChainModel) -> Bool {
        ((try? AddressFactory.accountId(from: address, chain: chain)) != nil)
    }
    
    func createChainAsset(for chain: ChainModel?) {
        if let chain = chain,
           let chainAsset = chain.utilityChainAssets().first,
           let address = address {
            delegate?.didReceive(chainAsset: chainAsset, address: address)
        }
    }
}

extension SendPrepareUseCase: SelectNetworkDelegate {
    func chainSelection(view _: SelectNetworkViewInput, didCompleteWith chain: ChainModel?) {
        createChainAsset(for: chain)
    }
}
