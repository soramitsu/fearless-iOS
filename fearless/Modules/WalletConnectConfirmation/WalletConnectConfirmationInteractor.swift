import UIKit
import FearlessWalletConnect

protocol WalletConnectConfirmationInteractorOutput: AnyObject {}

final class WalletConnectConfirmationInteractor {
    // MARK: - Private properties

    private weak var output: WalletConnectConfirmationInteractorOutput?

    private let walletConnect: WalletConnectService
    private let inputData: WalletConnectConfirmationInputData
    private let signer: WalletConnectSigner
    private let authorizer: WalletConnectSigningAuthorizing
    private let isSigningAllowed: (Blockchain) -> Bool

    init(
        walletConnect: WalletConnectService,
        inputData: WalletConnectConfirmationInputData,
        signer: WalletConnectSigner,
        authorizer: WalletConnectSigningAuthorizing,
        isSigningAllowed: @escaping (Blockchain) -> Bool = { WalletConnectSigningVeto.isSigningAllowed(on: $0) }
    ) {
        self.walletConnect = walletConnect
        self.inputData = inputData
        self.signer = signer
        self.authorizer = authorizer
        self.isSigningAllowed = isSigningAllowed
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
        let request = signingRequest.request
        // The remote config may pause signing for this network while the request is open, and the dApp may stop
        // waiting for it (it expires, or the session ends): both are checked before the PIN and again right before
        // the key is read, so nothing is signed or sent for a request nobody waits for.
        guard isSigningAllowed(request.chainId) else {
            throw WalletConnectSigningError.paused
        }
        guard await walletConnect.isPending(request: request) else {
            throw WalletConnectSigningError.requestEnded
        }

        // Nothing is signed until the user confirms with the PIN or biometrics.
        guard await authorizer.authorize() else {
            throw WalletConnectSigningError.notAuthorized
        }

        guard isSigningAllowed(request.chainId) else {
            throw WalletConnectSigningError.paused
        }
        guard await walletConnect.isPending(request: request) else {
            throw WalletConnectSigningError.requestEnded
        }

        let signature = try await signer.sign(request: signingRequest)
        let signDecision: WalletConnectSignDecision = .signed(request: request, signature: signature)
        do {
            try await walletConnect.submit(signDecision: signDecision)
        } catch WalletConnectClient.ClientError.requestNotFound, WalletConnectClient.ClientError.sessionNotFound {
            // The dApp stopped waiting in the moment the signature was made. A signature it never gets was not given;
            // a transaction already sent to the network was, and the person sees its hash.
            guard case .ethereumSendTransaction = signingRequest.method else {
                throw WalletConnectSigningError.requestEnded
            }
            return try? signature.get(String.self)
        }

        guard case .ethereumSendTransaction = signingRequest.method else {
            return nil
        }
        return try? signature.get(String.self)
    }

    func setup(with output: WalletConnectConfirmationInteractorOutput) {
        self.output = output
    }
}
