import Foundation
import BigInt
import RobinHood
import FearlessUtils

class MoonbeamContributionConfirmInteractor: CrowdloanContributionConfirmInteractor {
    private var moonbeamService: CrowdloanAgreementServiceProtocol
    private var ethereumAccountAddress: String?

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
        moonbeamService: CrowdloanAgreementServiceProtocol,
        logger: LoggerProtocol,
        crowdloanOperationFactory: CrowdloanOperationFactoryProtocol,
        connection: JSONRPCEngine,
        ethereumAddress: String? = nil
    ) {
        self.moonbeamService = moonbeamService
        ethereumAccountAddress = ethereumAddress

        super.init(
            paraId: paraId,
            selectedAccountAddress: selectedAccountAddress,
            chain: chain, assetId: assetId,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            signingWrapper: signingWrapper,
            accountRepository: accountRepository,
            crowdloanFundsProvider: crowdloanFundsProvider,
            singleValueProviderFactory: singleValueProviderFactory,
            bonusService: bonusService,
            operationManager: operationManager,
            logger: logger,
            crowdloanOperationFactory: crowdloanOperationFactory,
            connection: connection
        )
    }

    override func submit(contribution: BigUInt) {
        let prevContribution = crowdloanContribution?.balance ?? 0

        moonbeamService.makeSignature(
            previousTotalContribution: String(prevContribution),
            contribution: String(contribution)
        ) { [weak self] result in
            switch result {
            case let .success(makeSignatureData):
                self?.submitExtrinsic(
                    for: contribution,
                    signature: makeSignatureData.signature
                )
            case let .failure(error):
                self?.confirmPresenter?.didSubmitContribution(result: .failure(error))
            }
        }
    }

    private func addMemoIfNeeded(contribution: BigUInt) {
        guard
            let ethereumAccountAddress = ethereumAccountAddress,
            let memo = ethereumAccountAddress.data(using: .utf8)
        else {
            submit(contribution: contribution)
            return
        }

        let call = callFactory.addMemo(
            to: paraId,
            memo: memo
        )

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            let nextBuilder = try builder.adding(call: call)
            return nextBuilder
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                switch result {
                case .success:
                    self?.submit(contribution: contribution)
                case let .failure(error):
                    self?.confirmPresenter?.didSubmitContribution(result: .failure(error))
                }
            }
        )
    }

    private func saveEtheriumAdressAsMoonbeamDefault() {}
}
