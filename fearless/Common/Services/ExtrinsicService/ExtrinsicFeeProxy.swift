import Foundation

typealias ExtrinsicFeeId = String

protocol ExtrinsicFeeProxyDelegate: AnyObject {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for identifier: ExtrinsicFeeId)
}

protocol ExtrinsicFeeProxyProtocol: AnyObject {
    var delegate: ExtrinsicFeeProxyDelegate? { get set }

    func estimateFee(
        using service: ExtrinsicServiceProtocol,
        reuseIdentifier: ExtrinsicFeeId,
        setupBy closure: @escaping ExtrinsicBuilderClosure
    )
}

final class ExtrinsicFeeProxy {
    enum State {
        case loading
        case loaded(result: Result<RuntimeDispatchInfo, Error>)
    }

    private var feeStore: [ExtrinsicFeeId: State] = [:]

    weak var delegate: ExtrinsicFeeProxyDelegate?

    private func handle(result: Result<RuntimeDispatchInfo, Error>, for identifier: ExtrinsicFeeId) {
        switch result {
        case .success:
            feeStore[identifier] = .loaded(result: result)
        case .failure:
            feeStore[identifier] = nil
        }

        delegate?.didReceiveFee(result: result, for: identifier)
    }
}

extension ExtrinsicFeeProxy: ExtrinsicFeeProxyProtocol {
    func estimateFee(
        using service: ExtrinsicServiceProtocol,
        reuseIdentifier: ExtrinsicFeeId,
        setupBy closure: @escaping ExtrinsicBuilderClosure
    ) {
        if let state = feeStore[reuseIdentifier] {
            if case let .loaded(result) = state {
                delegate?.didReceiveFee(result: result, for: reuseIdentifier)
            }

            return
        }

        feeStore[reuseIdentifier] = .loading

        service.estimateFee(closure, runningIn: .main) { [weak self] result in
            self?.handle(result: result, for: reuseIdentifier)
        }
    }
}
