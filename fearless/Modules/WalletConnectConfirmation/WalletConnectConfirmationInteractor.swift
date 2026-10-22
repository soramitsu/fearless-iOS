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
        let request = inputData.signingRequest.request
        let signDecision: WalletConnectSignDecision = .rejected(request: request, error: .userRejected)
        try await walletConnect.submit(signDecision: signDecision)
    }

    func approve() async throws -> String? {
        let signingRequest = inputData.signingRequest
        let signature = try await signer.sign(request: signingRequest)
        let signDecision: WalletConnectSignDecision = .signed(request: signingRequest.request, signature: signature)
        try await walletConnect.submit(signDecision: signDecision)

        guard case .ethereumSendTransaction = signingRequest.method else {
            return nil
        }
        return try? signature.get(String.self)
    }

    func setup(with output: WalletConnectConfirmationInteractorOutput) {
        self.output = output
    }
}
