import Foundation
import BigInt
import RobinHood
import FearlessUtils
import SoraKeystore

class MoonbeamContributionConfirmInteractor: CrowdloanContributionConfirmInteractor {
    private let moonbeamService: CrowdloanAgreementServiceProtocol
    private let ethereumAccountAddress: String?
    private let selectedAccount: AccountItem

    init(
        paraId: ParaId,
        selectedAccount: AccountItem,
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
        ethereumAddress: String? = nil,
        settings: SettingsManagerProtocol
    ) {
        self.moonbeamService = moonbeamService
        ethereumAccountAddress = ethereumAddress
        self.selectedAccount = selectedAccount

        super.init(
            paraId: paraId,
            selectedAccountAddress: selectedAccount.address,
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
            connection: connection,
            settings: settings,
            memo: ethereumAddress
        )
    }

    override func makeMemoCall(memo: String?) -> RuntimeCall<CrowdloanAddMemo>? {
        guard let memo = memo, !memo.isEmpty,
              let memoData = try? Data(hexString: memo.lowercased()),
              self.settings.referralEthereumAddressForSelectedAccount() != memo
        else {
            return nil
        }

        return callFactory.addMemo(to: paraId, memo: memoData)
    }

    override func submit(contribution: BigUInt) {
        let prevContribution = crowdloanContribution?.balance ?? 0

        moonbeamService.makeSignature(
            previousTotalContribution: String(prevContribution),
            contribution: String(contribution)
        ) { [weak self] result in
            switch result {
            case let .success(makeSignatureData):
                self?.submitSignedContribution(
                    amount: contribution,
                    signature: makeSignatureData.signature
                )
            case let .failure(error):
                self?.confirmPresenter?.didSubmitContribution(result: .failure(error))
            }
        }
    }

    private func submitSignedContribution(amount: BigUInt, signature: String) {
        guard
            let signatureData = try? Data(hexString: signature),
            let multiSignature = MultiSignature.signature(from: selectedAccount.cryptoType, data: signatureData)
        else {
            confirmPresenter?.didSubmitContribution(result: .failure(CommonError.internal))
            return
        }

        let call = callFactory.contribute(to: paraId, amount: amount, multiSignature: multiSignature)

        let builderClosure: ExtrinsicBuilderClosure = { [weak self] builder in
            var nextBuilder = builder

            if let ethereumAccountAddress = self?.ethereumAccountAddress,
               let memoCall = self?.makeMemoCall(memo: ethereumAccountAddress) {
                nextBuilder = try nextBuilder.adding(call: memoCall)

                self?.saveEtheriumAdressAsMoonbeamDefault()
            }

            nextBuilder = try nextBuilder.adding(call: call)

            return nextBuilder
        }

        super.submitContribution(builderClosure: builderClosure)
    }

    private func saveEtheriumAdressAsMoonbeamDefault() {
        guard let ethereumAccountAddress = ethereumAccountAddress else { return }

        settings.saveReferralEthereumAddressForSelectedAccount(ethereumAccountAddress: ethereumAccountAddress)
    }
}
