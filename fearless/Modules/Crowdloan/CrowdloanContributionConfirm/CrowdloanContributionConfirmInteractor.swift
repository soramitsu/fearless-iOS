import UIKit
import RobinHood
import BigInt
import SSFModels

final class CrowdloanContributionConfirmInteractor: CrowdloanContributionInteractor, AccountFetching {
    var confirmPresenter: CrowdloanContributionConfirmInteractorOutputProtocol? {
        presenter as? CrowdloanContributionConfirmInteractorOutputProtocol
    }

    let signingWrapper: SigningWrapperProtocol
    let bonusService: CrowdloanBonusServiceProtocol?

    init(
        paraId: ParaId,
        selectedMetaAccount: MetaAccountModel,
        chainAsset: ChainAsset,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        jsonLocalSubscriptionFactory: JsonDataProviderFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        bonusService: CrowdloanBonusServiceProtocol?,
        operationManager: OperationManagerProtocol,
        existentialDepositService: ExistentialDepositServiceProtocol,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.signingWrapper = signingWrapper
        self.bonusService = bonusService

        super.init(
            paraId: paraId,
            selectedMetaAccount: selectedMetaAccount,
            chainAsset: chainAsset,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            crowdloanLocalSubscriptionFactory: crowdloanLocalSubscriptionFactory,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
                selectedMetaAccount: selectedMetaAccount
            ),
            priceLocalSubscriber: priceLocalSubscriber,
            jsonLocalSubscriptionFactory: jsonLocalSubscriptionFactory,
            operationManager: operationManager,
            existentialDepositService: existentialDepositService,
            callFactory: callFactory
        )
    }

    override func setup() {
        super.setup()

        do {
            if let accountResponse = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest()) {
                let displayAddress = try accountResponse.toDisplayAddress()
                confirmPresenter?.didReceiveDisplayAddress(result: .success(displayAddress))
            } else {
                confirmPresenter?.didReceiveDisplayAddress(
                    result: .failure(ChainAccountFetchingError.accountNotExists)
                )
            }
        } catch {
            confirmPresenter?.didReceiveDisplayAddress(result: .failure(error))
        }
    }

    private func submitExtrinsic(for contribution: BigUInt) {
        let call = callFactory.contribute(to: paraId, amount: contribution, multiSignature: nil)

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
}

extension CrowdloanContributionConfirmInteractor: CrowdloanContributionConfirmInteractorInputProtocol {
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
