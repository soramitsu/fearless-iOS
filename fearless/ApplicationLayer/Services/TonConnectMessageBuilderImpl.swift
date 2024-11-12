import Foundation
import SoraKeystore
import SSFModels
import WebKit
import TonSwift

final class TonConnectMessageBuilderImpl: TonConnectMessageBuilder {

    private enum Constants {
        static let windowKey = "Fearless"
    }

    func getConfiguration(
        userContentController: WKUserContentController
    ) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        let script = WKUserScript(
            source: dAppJsInjection(),
            injectionTime: WKUserScriptInjectionTime.atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(script)
        configuration.userContentController = userContentController
        return configuration
    }

    func getConnectEventSuccess(
        wallet: MetaAccountModel
    ) throws -> String {
        guard
            let address = wallet.ecosystem.tonAddress,
            let publicKey = wallet.ecosystem.tonPublicKey,
            let contract = wallet.ecosystem.tonWalletContract()
        else {
            throw ConvenienceError(error: "Missing TON")
        }

        let network = LocalToggleService.shared.tonEnvListToggle.storageValue ? TonConstants.testnetChainId : TonConstants.tonChainId
        let replyItem = TonConnect.ConnectItemReply.tonAddress(
            .init(
                address: address,
                network: Int16(network),
                publicKey: TonSwift.PublicKey(data: publicKey),
                walletStateInit: contract.stateInit
            )
        )
        let event = TonConnect.ConnectEventSuccess(
            payload: .init(
                items: [replyItem],
                device: .init()
            )
        )

        let string = try getString(from: event)
        return string
    }

    func getDappFunctionInvokeMessage(
        from body: Any
    ) throws -> DappFunctionInvokeMessage {
        guard
            let string = body as? String,
            let data = string.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = json["type"] as? String,
            let messageType = DappBridgeMessageType(rawValue: type),
            messageType == .invokeRnFunc,
            let name = json["name"] as? String,
            let functionType = DappBridgeFunctionType(rawValue: name),
            let invocationId = json["invocationId"] as? String,
            let args = json["args"] as? [Any]
        else {
            throw ConvenienceError(error: "Decoding error")
        }

        let message = DappFunctionInvokeMessage(
            type: functionType,
            invocationId: invocationId,
            args: args
        )

        return message
    }

    func getTonConnectAppRequest(
        from message: DappFunctionInvokeMessage
    ) throws -> TonConnect.AppRequest {
        guard message.args.isNotEmpty else {
            throw TonConnect.SendTransactionResponseError.ErrorCode.badRequest
        }
        let data = try JSONSerialization.data(withJSONObject: message.args[0])
        let request = try JSONDecoder().decode(TonConnect.AppRequest.self, from: data)
        return request
    }

    func getTonConnectRequestPayload(
        from message: DappFunctionInvokeMessage
    ) throws -> TonConnectRequestPayload {
        guard
            message.args.count >= 2,
            let connectPayload = message.args[1] as? [String: Any]
        else {
            throw ConvenienceError(error: "Invalidate message")
        }
        let data = try JSONSerialization.data(withJSONObject: connectPayload)
        let payload = try JSONDecoder().decode(TonConnectRequestPayload.self, from: data)
        return payload
    }

    func getConnectEventSuccessResponse(
        requestPayloadItems: [TonConnectRequestPayload.Item],
        wallet: MetaAccountModel,
        manifest: TonConnectManifest,
        tonChainModel: ChainModel
    ) throws -> TonConnect.ConnectEventSuccess {
        guard
            let address = wallet.ecosystem.tonAddress,
            let publicKey = wallet.ecosystem.tonPublicKey,
            let walletStateInit = wallet.ecosystem.tonWalletContract()?.stateInit
        else {
            throw ConvenienceError(error: "Missing TON")
        }

        let replyItems = try requestPayloadItems.compactMap { item in
            switch item {
            case .tonAddress:
                let network = LocalToggleService.shared.tonEnvListToggle.storageValue ? TonConstants.testnetChainId : TonConstants.tonChainId
                return TonConnect.ConnectItemReply.tonAddress(
                    .init(
                        address: address,
                        network: Int16(network),
                        publicKey: TonSwift.PublicKey(data: publicKey),
                        walletStateInit: walletStateInit
                    )
                )
            case let .tonProof(payload):
                guard let accountResponse = wallet.fetch(for: tonChainModel.accountRequest()) else {
                    throw ConvenienceError(error: "Missing account response")
                }
                let walletPrivateKey = try getSecretKey(
                    for: tonChainModel,
                    metaId: wallet.metaId,
                    accountResponse: accountResponse
                )
                return TonConnect.ConnectItemReply.tonProof(.success(.init(
                    address: address,
                    domain: manifest.host,
                    payload: payload,
                    privateKey: TonSwift.PrivateKey(data: walletPrivateKey)
                )))
            case .unknown:
                return nil
            }
        }
        let successEvent = TonConnect.ConnectEventSuccess(
            payload: .init(
                items: replyItems,
                device: .init()
            )
        )

        return successEvent
    }

    func encryptSuccessResponse(
        successResponse: TonConnect.ConnectEventSuccess,
        clientId: String,
        sessionCrypto: TonConnectSessionCrypto
    ) throws -> String {
        let responseData = try JSONEncoder().encode(successResponse)
        guard let receiverPublicKey = Data(tonHex: clientId) else {
            throw TonConnectServiceError.incorrectClientId
        }
        let response = try sessionCrypto.encrypt(
            message: responseData,
            receiverPublicKey: receiverPublicKey
        )
        let base64Response = response.base64EncodedString()
        return base64Response
    }

    func buildSendTransactionResponseError(
        sessionCrypto: TonConnectSessionCrypto,
        errorCode: TonConnect.SendTransactionResponseError.ErrorCode,
        id: String,
        clientId: String
    ) throws -> String {
        let response = TonConnect.SendTransactionResponse.error(.init(
            id: id,
            error: .init(code: errorCode, message: "")
        )
        )
        let transactionResponseData = try JSONEncoder().encode(response)
        guard let receiverPublicKey = Data(tonHex: clientId) else { return "" }

        let encryptedTransactionResponse = try sessionCrypto.encrypt(
            message: transactionResponseData,
            receiverPublicKey: receiverPublicKey
        )

        return encryptedTransactionResponse.base64EncodedString()
    }

    func buildSendTransactionResponseSuccess(
        sessionCrypto: TonConnectSessionCrypto,
        boc: String,
        id: String,
        clientId: String
    ) throws -> String {
        let response = TonConnect.SendTransactionResponse.success(
            .init(
                result: boc,
                id: id
            )
        )
        let transactionResponseData = try JSONEncoder().encode(response)
        guard let receiverPublicKey = Data(tonHex: clientId) else { return "" }

        let encryptedTransactionResponse = try sessionCrypto.encrypt(
            message: transactionResponseData,
            receiverPublicKey: receiverPublicKey
        )

        return encryptedTransactionResponse.base64EncodedString()
    }

    func getString(from event: Encodable) throws -> String {
        let data = try JSONEncoder().encode(event)
        guard let string = String(data: data, encoding: .utf8) else {
            throw ConvenienceError(error: "Encoding error")
        }
        return string
    }

    // MARK: - Private methods

    private func getSecretKey(
        for chain: ChainModel,
        metaId: String,
        accountResponse: ChainAccountResponse
    ) throws -> Data {
        let accountId = accountResponse.isChainAccount ? accountResponse.accountId : nil
        let tag: String = KeystoreTagV2.secretKeyTag(for: chain.ecosystem, metaId: metaId, accountId: accountId)

        let keystore = Keychain()
        let secretKey = try keystore.fetchKey(for: tag)
        return secretKey
    }

    private func dAppJsInjection() -> String {
        let deviceInfo = TonConnect.DeviceInfo()
        let info = Info(
            isWalletBrowser: true,
            deviceInfo: deviceInfo,
            protocolVersion: 2
        )
        guard
            let infoData = try? JSONEncoder().encode(info),
            var infoString = String(data: infoData, encoding: .utf8)
        else {
            return ""
        }
        infoString = String(describing: infoString).replacingOccurrences(of: "\\", with: "")
        return """
                (() => {
                                if (!window.\(Constants.windowKey)) {
                                    window.rnPromises = {};
                                    window.rnEventListeners = [];
                                    window.invokeRnFunc = (name, args, resolve, reject) => {
                                        const invocationId = btoa(Math.random()).substring(0, 12);
                                        const timeoutMs = null;
                                        const timeoutId = timeoutMs ? setTimeout(() => reject(new Error('bridge timeout for function with name: '+name+'')), timeoutMs) : null;
                                        window.rnPromises[invocationId] = { resolve, reject, timeoutId }
                                        window.webkit.messageHandlers.dapp.postMessage(JSON.stringify({
                                            type: '\(DappBridgeMessageType.invokeRnFunc.rawValue)',
                                            invocationId: invocationId,
                                            name,
                                            args,
                                        }));
                                    };

                                    window.addEventListener('message', ({ data }) => {
                                        try {
                                            const message = data;
                                            console.log('message bridge', JSON.stringify(message));
                                            if (message.type === '\(DappBridgeMessageType.functionResponse.rawValue)') {
                                                const promise = window.rnPromises[message.invocationId];

                                                if (!promise) {
                                                    return;
                                                }

                                                if (promise.timeoutId) {
                                                    clearTimeout(promise.timeoutId);
                                                }

                                                if (message.status === 'fulfilled') {
                                                    promise.resolve(JSON.parse(message.data));
                                                } else {
                                                    promise.reject(new Error(message.data));
                                                }

                                                delete window.rnPromises[message.invocationId];
                                            }

                                            if (message.type === '\(DappBridgeMessageType.event.rawValue)') {
                                                window.rnEventListeners.forEach((listener) => listener(message.event));
                                            }
                                        } catch { }
                                    });
                                }

                                const listen = (cb) => {
                                    window.rnEventListeners.push(cb);
                                    return () => {
                                        const index = window.rnEventListeners.indexOf(cb);
                                        if (index > -1) {
                                            window.rnEventListeners.splice(index, 1);
                                        }
                                    };
                                };

                                window.\(Constants.windowKey) = {
                                    tonconnect: Object.assign(\(infoString),{ send: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('send', args, resolve, reject))},connect: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('connect', args, resolve, reject))},restoreConnection: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('restoreConnection', args, resolve, reject))},disconnect: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('disconnect', args, resolve, reject))} },{ listen }),
                                }
                            })();
        """
    }
}
