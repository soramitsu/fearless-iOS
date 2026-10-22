import UIKit

protocol WalletConnectConfirmationInteractorOutput: AnyObject {}

final class WalletConnectConfirmationInteractor {
    // MARK: - Private properties

    private weak var output: WalletConnectConfirmationInteractorOutput?

    private let walletConnect: WalletConnectService
    private let inputData: WalletConnectConfirmationInputData
    private let signer: WalletConnectSigner
    private let authorizer: WalletConnectSigningAuthorizing

    init(
        walletConnect: WalletConnectService,
        inputData: WalletConnectConfirmationInputData,
        signer: WalletConnectSigner,
        authorizer: WalletConnectSigningAuthorizing
    ) {
        self.walletConnect = walletConnect
        self.inputData = inputData
        self.signer = signer
        self.authorizer = authorizer
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
        // Nothing is signed until the user confirms with the PIN or biometrics.
        guard await authorizer.authorize() else {
            throw WalletConnectSigningError.notAuthorized
        }

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
