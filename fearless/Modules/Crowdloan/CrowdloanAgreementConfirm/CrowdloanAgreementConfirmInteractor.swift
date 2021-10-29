import UIKit
import FearlessUtils
import RobinHood
import BigInt

final class CrowdloanAgreementConfirmInteractor: AccountFetching {
    var presenter: CrowdloanAgreementConfirmInteractorOutputProtocol?

    private let signingWrapper: SigningWrapperProtocol
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let agreementService: CrowdloanAgreementServiceProtocol
    private var paraId: ParaId
    private var selectedAccountAddress: AccountAddress
    private var chain: Chain
    private var assetId: WalletAssetId
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var extrinsicService: ExtrinsicServiceProtocol
    private var callFactory: SubstrateCallFactoryProtocol
    private var operationManager: OperationManagerProtocol
    internal var singleValueProviderFactory: SingleValueProviderFactoryProtocol
    private var remark: String
    private let webSocketService: WebSocketServiceProtocol
    private let logger: LoggerProtocol

    private var submitAndWatchExtrinsicSubscriptionId: UInt16?

    init(
        paraId: ParaId,
        selectedAccountAddress: AccountAddress,
        chain: Chain,
        assetId: WalletAssetId,
        extrinsicService: ExtrinsicServiceProtocol,
        signingWrapper: SigningWrapperProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        agreementService: CrowdloanAgreementServiceProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        operationManager: OperationManagerProtocol,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        remark: String,
        webSocketService: WebSocketServiceProtocol,
        logger: LoggerProtocol
    ) {
        self.signingWrapper = signingWrapper
        self.accountRepository = accountRepository
        self.agreementService = agreementService
        self.paraId = paraId
        self.selectedAccountAddress = selectedAccountAddress
        self.chain = chain
        self.assetId = assetId
        self.extrinsicService = extrinsicService
        self.callFactory = callFactory
        self.operationManager = operationManager
        self.singleValueProviderFactory = singleValueProviderFactory
        self.remark = remark
        self.webSocketService = webSocketService
        self.logger = logger
    }

    private func verifyRemark(
        extrinsicHash: String,
        blockHash: String
    ) {
        agreementService.verifyRemark(extrinsicHash: extrinsicHash, blockHash: blockHash) { result in
            switch result {
            case let .success(verifyRemarkData):
                if verifyRemarkData.verified {
                    self.presenter?.didReceiveVerifiedExtrinsicHash(result: .success(extrinsicHash))
                } else {
                    self.presenter?.didReceiveVerifiedExtrinsicHash(result: .failure(CommonError.internal))
                }
            case let .failure(error):
                self.presenter?.didReceiveVerifiedExtrinsicHash(result: .failure(error))
            }
        }
    }

    deinit {
        if let identifier = submitAndWatchExtrinsicSubscriptionId {
            webSocketService.connection?.cancelForIdentifier(identifier)
        }
    }
}

extension CrowdloanAgreementConfirmInteractor: CrowdloanAgreementConfirmInteractorInputProtocol {
    func setup() {
        fetchAccount(
            for: selectedAccountAddress,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            guard let strongSelf = self else {
                return
            }

            switch result {
            case let .success(maybeAccountItem):
                let displayAddress = maybeAccountItem.map {
                    DisplayAddress(address: $0.address, username: $0.username)
                } ?? DisplayAddress(address: strongSelf.selectedAccountAddress, username: "")

                strongSelf.presenter?.didReceiveDisplayAddress(result: .success(displayAddress))
            case let .failure(error):
                strongSelf.presenter?.didReceiveDisplayAddress(result: .failure(error))
            }
        }

        estimateFee()
        priceProvider = subscribeToPriceProvider(for: assetId)
    }

    func estimateFee() {
        guard let data = remark.data(using: .utf8) else {
            presenter?.didReceiveFee(result: .failure(CommonError.internal))
            return
        }

        let closure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let call = self?.callFactory.addRemark(data) else {
                throw CommonError.internal
            }

            _ = try builder.adding(call: call)
            return builder
        }

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            self?.presenter?.didReceiveFee(result: result)
        }
    }

    func confirmAgreement() {
        guard let data = remark.data(using: .utf8) else {
            presenter?.didReceiveFee(result: .failure(CommonError.internal))
            return
        }

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()
            let remarkCall = try callFactory.addRemark(data)
            return try builder.adding(call: remarkCall)
        }

        extrinsicService.submitAndWatch(
            closure, signer:
            signingWrapper,
            runningIn: .main
        ) { [weak self] result, exHash in

            let updateClosure: (JSONRPCSubscriptionUpdate<ExtrinsicStatus>) -> Void = { [weak self] statusUpdate in
                let state = statusUpdate.params.result
                switch state {
                case let .finalized(block):
                    self?.logger.info("extrinsic finalized \(block)")
                    guard let extrinsicHash = exHash else {
                        return
                    }

                    self?.verifyRemark(extrinsicHash: extrinsicHash, blockHash: block)

                default:
                    self?.logger.info("extrinsic status \(state)")
                    // TODO: Alert
                }
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger.error("Did receive subscription error: \(error) \(unsubscribed)")
                // TODO: Alert
            }
            switch result {
            case let .success(hash):
                do {
                    self?.logger.debug("extrinsic hash: \(hash)")
                    guard let params: String = hash.data(using: .utf8)?.toHex(includePrefix: true) else {
                        throw CommonError.internal
                    }
                    self?.logger.debug("extrinsic hash parameter: \(params)")

                    self?.submitAndWatchExtrinsicSubscriptionId = try self?.webSocketService.connection?.subscribe(
                        "author_submitAndWatchExtrinsic",
                        params: [params],
                        updateClosure: updateClosure,
                        failureClosure: failureClosure
                    )
                } catch {
                    self?.logger.error("Can't subscribe to storage: \(error)")
                    // TODO: Alert
                }
            case let .failure(error):
                self?.logger.error("submit and watch request error: \(error)")
            }
        }
    }
}

extension CrowdloanAgreementConfirmInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter?.didReceivePriceData(result: result)
    }
}
