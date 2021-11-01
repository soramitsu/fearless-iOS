import UIKit
import RobinHood
import BigInt
import FearlessUtils

class CrowdloanContributionConfirmInteractor: CrowdloanContributionInteractor, AccountFetching, CrowdloanContributionConfirmInteractorInputProtocol {
    var confirmPresenter: CrowdloanContributionConfirmInteractorOutputProtocol? {
        presenter as? CrowdloanContributionConfirmInteractorOutputProtocol
    }

    let signingWrapper: SigningWrapperProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let bonusService: CrowdloanBonusServiceProtocol?

    init(
        paraId: ParaId,
        selectedAccountAddress: AccountAddress,
        chain: Chain,
        assetId: WalletAssetId,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signingWrapper: SigningWrapperProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        crowdloanFundsProvider: AnyDataProvider<DecodedCrowdloanFunds>,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        bonusService: CrowdloanBonusServiceProtocol?,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol,
        crowdloanOperationFactory: CrowdloanOperationFactoryProtocol,
        connection: JSONRPCEngine
    ) {
        self.signingWrapper = signingWrapper
        self.accountRepository = accountRepository
        self.bonusService = bonusService

        super.init(
            paraId: paraId,
            selectedAccountAddress: selectedAccountAddress,
            chain: chain,
            assetId: assetId,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            crowdloanFundsProvider: crowdloanFundsProvider,
            singleValueProviderFactory: singleValueProviderFactory,
            operationManager: operationManager,
            logger: logger,
            crowdloanOperationFactory: crowdloanOperationFactory,
            connection: connection
        )
    }

    override func setup() {
        super.setup()

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

                strongSelf.confirmPresenter?.didReceiveDisplayAddress(result: .success(displayAddress))
            case let .failure(error):
                strongSelf.confirmPresenter?.didReceiveDisplayAddress(result: .failure(error))
            }
        }
    }

    func submitExtrinsic(for contribution: BigUInt, signature: String? = nil) {
        let call = callFactory.contribute(
            to: paraId,
            amount: contribution,
            signature: signature
        )

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            let nextBuilder = try builder.adding(call: call)
            return try self.bonusService?.applyOnchainBonusForContribution(
                amount: contribution,
                using: nextBuilder
            ) ?? nextBuilder
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.confirmPresenter?.didSubmitContribution(result: result)
            }
        )
    }

    /* CrowdloanContributionConfirmInteractorInputProtocol */
    func submit(contribution: BigUInt) {
        if let bonusService = bonusService {
            bonusService.applyOffchainBonusForContribution(amount: contribution) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.submitExtrinsic(for: contribution)
                    case let .failure(error):
                        self?.confirmPresenter?.didSubmitContribution(result: .failure(error))
                    }
                }
            }
        } else {
            submitExtrinsic(for: contribution)
        }
    }

    func estimateFee(for contribution: BigUInt) {
        estimateFee(for: contribution, bonusService: bonusService)
    }
}
