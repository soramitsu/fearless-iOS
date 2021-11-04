import UIKit
import RobinHood
import BigInt
import FearlessUtils
import SoraKeystore

class CrowdloanContributionConfirmInteractor: CrowdloanContributionInteractor,
    CrowdloanContributionConfirmInteractorInputProtocol,
    AccountFetching {
    var confirmPresenter: CrowdloanContributionConfirmInteractorOutputProtocol? {
        presenter as? CrowdloanContributionConfirmInteractorOutputProtocol
    }

    let signingWrapper: SigningWrapperProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let bonusService: CrowdloanBonusServiceProtocol?

    private var memo: String?

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
        connection: JSONRPCEngine,
        settings: SettingsManagerProtocol,
        memo: String?
    ) {
        self.signingWrapper = signingWrapper
        self.accountRepository = accountRepository
        self.bonusService = bonusService
        self.memo = memo

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
            connection: connection,
            settings: settings
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

    private func prepareAndContribute(with amount: BigUInt) {
        let call = callFactory.contribute(
            to: paraId,
            amount: amount,
            multiSignature: nil
        )

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            let nextBuilder = try builder.adding(call: call)
            return try self.bonusService?.applyOnchainBonusForContribution(
                amount: amount,
                using: nextBuilder
            ) ?? nextBuilder
        }

        submitContribution(builderClosure: builderClosure)
    }

    func submitContribution(builderClosure: @escaping ExtrinsicBuilderClosure) {
        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.confirmPresenter?.didSubmitContribution(result: result)
            }
        )
    }

    func estimateFee(for contribution: BigUInt) {
        estimateFee(
            for: contribution,
            bonusService: bonusService,
            memo: memo
        )
    }

    func submit(contribution: BigUInt) {
        if let bonusService = bonusService {
            bonusService.applyOffchainBonusForContribution(amount: contribution) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.prepareAndContribute(with: contribution)
                    case let .failure(error):
                        self?.confirmPresenter?.didSubmitContribution(result: .failure(error))
                    }
                }
            }
        } else {
            prepareAndContribute(with: contribution)
        }
    }
}
