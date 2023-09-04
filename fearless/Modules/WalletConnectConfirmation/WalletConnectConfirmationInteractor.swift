import UIKit

protocol WalletConnectConfirmationInteractorOutput: AnyObject {}

final class WalletConnectConfirmationInteractor {
    // MARK: - Private properties

    private weak var output: WalletConnectConfirmationInteractorOutput?

    private let walletConnect: WalletConnectService
    private let inputData: WalletConnectConfirmationInputData
    private let signer: WalletConnectSigner

    init(
        walletConnect: WalletConnectService,
        inputData: WalletConnectConfirmationInputData,
        signer: WalletConnectSigner
    ) {
        self.walletConnect = walletConnect
        self.inputData = inputData
        self.signer = signer
    }
}

// MARK: - WalletConnectConfirmationInteractorInput

extension WalletConnectConfirmationInteractor: WalletConnectConfirmationInteractorInput {
    func reject() async throws {
        let signDecision: WalletConnectSignDecision = .rejected(request: inputData.resuest, error: .userRejected)
        try await walletConnect.submit(signDecision: signDecision)
    }

    func approve() async throws -> String? {
        let signature = try await signer.sign(
            params: inputData.payload.payload,
            chain: inputData.chain,
            method: inputData.method
        )
        let signDecision: WalletConnectSignDecision = .signed(request: inputData.resuest, signature: signature)
        try await walletConnect.submit(signDecision: signDecision)

        guard case .ethereumSendTransaction = inputData.method else {
            return nil
        }
        return try? signature.get(String.self)
    }

    func setup(with output: WalletConnectConfirmationInteractorOutput) {
        self.output = output
    }
}
