import UIKit
import WalletConnectSign
import SSFTransferService

protocol WalletConnectConfirmationInteractorOutput: AnyObject {}

final class WalletConnectConfirmationInteractor {
    // MARK: - Private properties

    private weak var output: WalletConnectConfirmationInteractorOutput?

    private let walletConnect: WalletConnectService
    private let inputData: WalletConnectConfirmationInputData
    private let signer: WalletConnectSigner
    private let tonConnectService: TonConnectService

    init(
        walletConnect: WalletConnectService,
        inputData: WalletConnectConfirmationInputData,
        signer: WalletConnectSigner,
        tonConnectService: TonConnectService
    ) {
        self.walletConnect = walletConnect
        self.inputData = inputData
        self.signer = signer
        self.tonConnectService = tonConnectService
    }

    // MARK: - Private methods

    private func approveWalletConnect(
        resuest: Request,
        method: WalletConnectMethod
    ) async throws -> String? {
        let signature = try await signer.sign(
            params: inputData.payload.payload,
            chain: inputData.chain,
            method: method
        )
        let signDecision: WalletConnectSignDecision = .signed(
            request: resuest,
            signature: signature
        )
        try await walletConnect.submit(signDecision: signDecision)

        guard case .ethereumSendTransaction = method else {
            return nil
        }
        return try? signature.get(String.self)
    }

    private func approveTonTonJsBridge(
        request: TonConnect.AppRequest
    ) async throws -> String {
        guard let parameter = request.params.first else {
            throw ConvenienceError(error: "Missing Ton params")
        }
        let boc = try await tonConnectService.approveTonConnect(
            wallet: inputData.wallet,
            parameter: parameter
        )
        return boc
    }

    private func confirmTonConnect(
        request: TonConnect.AppRequest,
        app: TonConnectApp
    ) async throws {
        guard let parameter = request.params.first else {
            throw ConvenienceError(error: "Missing Ton params")
        }

        try await tonConnectService.confirmRequest(
            wallet: inputData.wallet,
            appRequest: request,
            app: app,
            parameter: parameter
        )
    }
}

// MARK: - WalletConnectConfirmationInteractorInput

extension WalletConnectConfirmationInteractor: WalletConnectConfirmationInteractorInput {
    func approve() async throws -> String? {
        switch inputData.variant {
        case let .walletConnect(request, _, method):
            return try await approveWalletConnect(
                resuest: request,
                method: method
            )
        case let .tonJsBridge(_, _, request, _):
            return try await approveTonTonJsBridge(request: request)
        case let .tonConnect(request: request, app: app):
            try await confirmTonConnect(request: request, app: app)
            return nil
        }
    }

    func cancelTonConnect(
        appRequest: TonConnect.AppRequest,
        app: TonConnectApp
    ) async throws {
        try await tonConnectService.cancelRequest(
            appRequest: appRequest,
            app: app
        )
    }

    func setup(with output: WalletConnectConfirmationInteractorOutput) {
        self.output = output
    }
}
