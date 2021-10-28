import UIKit
import FearlessUtils
import RobinHood
import BigInt

final class CrowdloanAgreementConfirmInteractor: AccountFetching, CrowdloanAgreementConfirmInteractorInputProtocol {
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
        remark: String
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
    }

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
}

extension CrowdloanAgreementConfirmInteractor {
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

        let closure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let call = self?.callFactory.addRemark(data) else {
                throw CommonError.internal
            }

            _ = try builder.adding(call: call)
            return builder
        }

        extrinsicService.submit(closure, signer: signingWrapper, runningIn: .main) { [weak self] _ in
//            self?.presenter?.didReceiveFee(result: result)
        }
    }
}

extension CrowdloanAgreementConfirmInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter?.didReceivePriceData(result: result)
    }
}
