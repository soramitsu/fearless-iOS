import UIKit
import RobinHood
import FearlessUtils

enum SignerConfirmInteractorError: Error {
    case requestParseError
    case missingCall
    case signerFailed
}

final class SignerConfirmInteractor {
    weak var presenter: SignerConfirmInteractorOutputProtocol!

    let selectedAccount: AccountItem
    let assetId: WalletAssetId
    let request: SignerOperationRequestProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let signer: SigningWrapperProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let operationManager: OperationManagerProtocol

    private var call: RuntimeCall<JSON>?

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?

    init(
        selectedAccount: AccountItem,
        assetId: WalletAssetId,
        request: SignerOperationRequestProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.assetId = assetId
        self.request = request
        self.runtimeService = runtimeService
        self.signer = signer
        self.extrinsicService = extrinsicService
        self.singleValueProviderFactory = singleValueProviderFactory
        self.operationManager = operationManager
    }

    private func setupExtractingExtrinsicDetails(from data: Data) {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let decodingOperation: BaseOperation<(RuntimeCall<JSON>, String)> = ClosureOperation {
            let coderFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let decoder = try coderFactory.createDecoder(from: data)
            let jsonCall: JSON = try decoder.read(of: GenericType.call.name)
            let jsonExtra: JSON = try decoder.read(type: GenericType.extrinsicExtra.name)
            let extrinsicDic = jsonCall.dictValue?.merging(
                jsonExtra.dictValue ?? [:],
                uniquingKeysWith: { first, _ in first }
            ) ?? [:]

            let call = try jsonCall.map(to: RuntimeCall<JSON>.self)

            let extrinsicData = try JSONEncoder().encode(extrinsicDic)

            return (call, String(data: extrinsicData, encoding: .utf8) ?? "")
        }

        decodingOperation.addDependency(codingFactoryOperation)

        decodingOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let (call, extrinsicString) = try decodingOperation.extractNoCancellableResultData()
                    self?.saveAndNotify(with: call, extrinsicString: extrinsicString)
                } catch {
                    self?.presenter.didExtractRequest(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: [codingFactoryOperation, decodingOperation], in: .transient)
    }

    private func saveAndNotify(with call: RuntimeCall<JSON>, extrinsicString: String) {
        self.call = call

        let model: SignerConfirmation = {
            let transfer = try? call.args.map(to: TransferCall.self)
            return SignerConfirmation(
                moduleName: call.moduleName,
                callName: call.callName,
                amount: transfer?.value,
                extrinsicString: extrinsicString
            )
        }()

        presenter.didExtractRequest(result: .success(model))

        estimateFee(for: call)
    }

    private func estimateFee(for call: RuntimeCall<JSON>) {
        let closure: ExtrinsicBuilderClosure = { builder in
            try builder.adding(call: call)
        }

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            self?.presenter.didReceiveFee(result: result)
        }
    }

    private func prepareAndSubmitSignature() {
        do {
            let rawSignature = try signer.sign(request.signingPayload).rawData()

            let signature: MultiSignature

            switch selectedAccount.cryptoType {
            case .sr25519:
                signature = .sr25519(data: rawSignature)
            case .ed25519:
                signature = .ed25519(data: rawSignature)
            case .ecdsa:
                signature = .ecdsa(data: rawSignature)
            }

            let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let encodingOperation: BaseOperation<Data> = ClosureOperation {
                let factory = try coderFactoryOperation.extractNoCancellableResultData()
                let encoder = factory.createEncoder()
                try encoder.append(signature, ofType: KnownType.signature.name)
                return try encoder.encode()
            }

            encodingOperation.addDependency(coderFactoryOperation)

            encodingOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    do {
                        let encodedData = try encodingOperation.extractNoCancellableResultData()
                        self?.submitSignatureAndNotify(encodedData)
                    } catch {
                        self?.presenter.didReceiveSubmition(result: .failure(error))
                    }
                }
            }

            operationManager.enqueue(operations: [coderFactoryOperation, encodingOperation], in: .transient)
        } catch {
            presenter.didReceiveSubmition(result: .failure(SignerConfirmInteractorError.signerFailed))
        }
    }

    private func submitSignatureAndNotify(_ encodedSignature: Data) {
        request.submit(signature: encodedSignature) { [weak self] result in
            self?.presenter.didReceiveSubmition(result: result)
        }
    }
}

extension SignerConfirmInteractor: SignerConfirmInteractorInputProtocol {
    func setup() {
        setupExtractingExtrinsicDetails(from: request.signingPayload)

        priceProvider = subscribeToPriceProvider(for: assetId)
        accountInfoProvider = subscribeToAccountInfoProvider(
            for: selectedAccount.address,
            runtimeService: runtimeService
        )
    }

    func confirm() {
        guard call != nil else {
            presenter.didReceiveSubmition(result: .failure(SignerConfirmInteractorError.missingCall))
            return
        }

        prepareAndSubmitSignature()
    }

    func refreshFee() {
        guard let call = call else {
            presenter.didReceiveFee(result: .failure(SignerConfirmInteractorError.missingCall))
            return
        }

        estimateFee(for: call)
    }
}

extension SignerConfirmInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePrice(result: result)
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }
}
