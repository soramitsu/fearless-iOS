import Foundation
import SSFModels

/// Owns one confirmation task without retaining its UI. Cancellation revokes future work and
/// delivery; the service remains responsible for retaining any already admitted payment.
final class SolanaSendAttempt {
    private let lock = NSLock()
    private let asset: ChainAsset
    private let selection: SelectedWalletAuthority.Lease
    var isSelectionCurrent: Bool { selection.isCurrent }
    private let call: SendConfirmTransferCall
    private let prepare: (ChainAsset) async throws -> TransferServiceProtocol
    private var identity: UUID?
    private var ownedTask: Task<Void, Never>?

    var task: Task<Void, Never>? {
        lock.lock()
        defer { lock.unlock() }
        return ownedTask
    }

    init(
        asset: ChainAsset,
        call: SendConfirmTransferCall,
        selection: SelectedWalletAuthority.Lease,
        prepare: @escaping (ChainAsset) async throws -> TransferServiceProtocol
    ) {
        self.asset = asset
        self.call = call
        self.selection = selection
        self.prepare = prepare
    }

    deinit {
        ownedTask?.cancel()
    }

    func start(retryHash: String?, completion: @escaping (Swift.Result<String, Error>) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard identity == nil, selection.isCurrent else { return }
        let attempt = UUID()
        identity = attempt
        let prepare = prepare
        let asset = asset
        let call = call
        let selection = selection
        ownedTask = Task { [weak self] in
            await SolanaSendAuthorization.$selection.withValue(selection) {
                let result: Swift.Result<String, Error>
                do {
                    try SolanaSendAuthorization.requireCurrent()
                    let service = try await prepare(asset)
                    try SolanaSendAuthorization.requireCurrent()
                    let hash: String
                    if let retryHash {
                        hash = try await service.retryUnresolvedTransfer(hash: retryHash)
                    } else {
                        switch call {
                        case let .transfer(transfer): hash = try await service.submit(transfer: transfer)
                        case let .xorlessTransfer(transfer): hash = try await service.submit(transfer: transfer)
                        }
                    }
                    result = .success(hash)
                } catch {
                    result = .failure(error)
                }
                await MainActor.run { [weak self] in
                    guard let self, self.finish(attempt), selection.isCurrent else { return }
                    completion(result)
                }
            }
        }
    }

    func cancel() {
        lock.lock()
        identity = nil
        let task = ownedTask
        lock.unlock()
        task?.cancel()
    }

    private func finish(_ attempt: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard identity == attempt else { return false }
        identity = nil
        return true
    }
}
