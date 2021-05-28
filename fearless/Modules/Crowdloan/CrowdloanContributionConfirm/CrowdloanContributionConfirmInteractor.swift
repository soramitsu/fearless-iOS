import UIKit
import RobinHood
import BigInt

final class CrowdloanContributionConfirmInteractor: CrowdloanContributionInteractor, AccountFetching {
    var confirmPresenter: CrowdloanContributionConfirmInteractorOutputProtocol? {
        presenter as? CrowdloanContributionConfirmInteractorOutputProtocol
    }

    let signingWrapper: SigningWrapperProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>

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
        operationManager: OperationManagerProtocol
    ) {
        self.signingWrapper = signingWrapper
        self.accountRepository = accountRepository

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
            operationManager: operationManager
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
}

extension CrowdloanContributionConfirmInteractor: CrowdloanContributionConfirmInteractorInputProtocol {
    func submit(contribution: BigUInt) {
        let call = callFactory.contribute(to: paraId, amount: contribution)

        extrinsicService.submit(
            { builder in
                try builder.adding(call: call)
            },
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.confirmPresenter?.didSubmitContribution(result: result)
            }
        )
    }
}
