import Foundation
import Web3
import BigInt
import SoraFoundation
import IrohaCrypto
import SwiftUI
import SSFModels

struct SendLoadingCollector {
    var feeReady: Bool = false
    var balanceReady: Bool = false
    var utilityBalanceReady: Bool = false
    var edReady: Bool = false

    mutating func reset(isUtility: Bool) {
        feeReady = false
        balanceReady = false
        utilityBalanceReady = !isUtility
        edReady = false
    }

    var isReady: Bool {
        [
            feeReady,
            balanceReady,
            utilityBalanceReady,
            edReady
        ].allSatisfy { $0 }
    }
}

final class WalletSendConfirmPresenter {
    weak var view: WalletSendConfirmViewProtocol?
    private let wireframe: WalletSendConfirmWireframeProtocol
    private let interactor: WalletSendConfirmInteractorInputProtocol
    private let accountViewModelFactory: AccountViewModelFactoryProtocol
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol?
    private let chainAsset: ChainAsset
    private let call: SendConfirmTransferCall
    private let wallet: MetaAccountModel
    private let walletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactoryProtocol
    private let scamInfo: ScamInfo?
    private var feeViewModel: BalanceViewModelProtocol?

    private var balance: Decimal?
    private var utilityBalance: Decimal?
    private var priceData: PriceData?
    private var utilityPriceData: PriceData?
    private var fee: Decimal?
    private var minimumBalance: BigUInt?
    private var eqUilibriumTotalBalance: Decimal?

    private var loadingCollector = SendLoadingCollector()

    init(
        interactor: WalletSendConfirmInteractorInputProtocol,
        wireframe: WalletSendConfirmWireframeProtocol,
        accountViewModelFactory: AccountViewModelFactoryProtocol,
        dataValidatingFactory: SendDataValidatingFactory,
        walletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactoryProtocol,
        logger: LoggerProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        call: SendConfirmTransferCall,
        scamInfo: ScamInfo?,
        feeViewModel: BalanceViewModelProtocol?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.accountViewModelFactory = accountViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.walletSendConfirmViewModelFactory = walletSendConfirmViewModelFactory
        self.logger = logger
        self.chainAsset = chainAsset
        self.call = call
        self.wallet = wallet
        self.scamInfo = scamInfo
        self.feeViewModel = feeViewModel
        self.localizationManager = localizationManager
        if let feeViewModel {
            fee = Decimal(string: feeViewModel.amount)
        }
        loadingCollector.feeReady = feeViewModel != nil
    }

    private func provideViewModel() {
        Task {
            let amount = Decimal.fromSubstrateAmount(call.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
            let parameters = WalletSendConfirmViewModelFactoryParameters(
                amount: amount,
                senderAccountViewModel: provideSenderAccountViewModel(),
                receiverAccountViewModel: provideReceiverAccountViewModel(),
                assetBalanceViewModel: try await provideAssetVewModel(),
                tipRequired: chainAsset.chain.isTipRequired,
                tipViewModel: try await provideTipViewModel(),
                feeViewModel: feeViewModel,
                wallet: wallet,
                locale: selectedLocale,
                scamInfo: scamInfo,
                assetModel: chainAsset.asset
            )
            let viewModel = walletSendConfirmViewModelFactory.buildViewModel(
                parameters: parameters
            )

            await MainActor.run {
                self.view?.didReceive(state: .loaded(viewModel))
            }
        }
    }

    private func provideReceiverAccountViewModel() -> AccountViewModel? {
        let title = R.string.localizable
            .walletSendReceiverTitle(preferredLanguages: selectedLocale.rLanguages)

        return accountViewModelFactory.buildViewModel(
            title: title,
            address: call.receiverAddress,
            locale: selectedLocale
        )
    }

    private func provideSenderAccountViewModel() -> AccountViewModel? {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
              let senderAddress = try? AddressFactory.address(for: accountId, chain: chainAsset.chain)
        else {
            return nil
        }

        let title = R.string.localizable
            .transactionDetailsFrom(preferredLanguages: selectedLocale.rLanguages)

        return accountViewModelFactory.buildViewModel(
            title: title,
            address: senderAddress,
            locale: selectedLocale
        )
    }

    private func provideAssetVewModel() async throws -> AssetBalanceViewModelProtocol? {
        let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: chainAsset)
        let amount = Decimal.fromSubstrateAmount(call.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
        return balanceViewModelFactory?.createAssetBalanceViewModel(
            amount,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)
    }

    private func provideTipViewModel() async throws -> BalanceViewModelProtocol? {
        guard
            let utilityAsset = interactor.getFeePaymentChainAsset(for: chainAsset),
            let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: utilityAsset)
        else { return nil }

        let tip = Decimal.fromSubstrateAmount(call.tip ?? .zero, precision: Int16(chainAsset.asset.precision))
        return tip
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData, usageCase: .detailsCrypto) }?
            .value(for: selectedLocale)
    }

    private func updateFeeViewModel() {
        guard
            let utilityAsset = interactor.getFeePaymentChainAsset(for: chainAsset),
            let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: utilityAsset)
        else {
            return
        }

        let viewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: utilityPriceData, usageCase: .detailsCrypto) }?
            .value(for: selectedLocale)
        feeViewModel = viewModel
    }

    private func buildBalanceViewModelFactory(
        wallet: MetaAccountModel,
        for chainAsset: ChainAsset?
    ) -> BalanceViewModelFactoryProtocol? {
        guard let chainAsset = chainAsset else {
            return nil
        }
        let assetInfo = chainAsset.asset
            .displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )
        return balanceViewModelFactory
    }

    private func validateAndSubmitTransfer() {
        let amount = Decimal.fromSubstrateAmount(call.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
        let tipPaymentChainAsset = interactor.getFeePaymentChainAsset(for: chainAsset)
        let tipPaymentPrecision = tipPaymentChainAsset?.asset.precision ?? chainAsset.asset.precision
        let tip = Decimal.fromSubstrateAmount(call.tip ?? .zero, precision: Int16(tipPaymentPrecision)) ?? .zero

        let balanceType: BalanceType = (!chainAsset.isUtility && chainAsset.chain.isUtilityFeePayment) ?
            .orml(balance: balance, utilityBalance: utilityBalance) : .utility(balance: balance)

        DataValidationRunner(validators: [
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: balanceType,
                feeAndTip: (fee ?? 0) + tip,
                sendAmount: amount,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.view?.didStartLoading()
            strongSelf.interactor.submitExtrinsic()
        }
    }

    private func submitXorlessTransfer() {
        view?.didStartLoading()
        interactor.submitExtrinsic()
    }

    private func checkLoadingState() {
        DispatchQueue.main.async { [unowned self] in
            self.view?.didReceive(isLoading: !self.loadingCollector.isReady)
        }
    }
}

extension WalletSendConfirmPresenter: WalletSendConfirmPresenterProtocol {
    func didTapScamWarningButton() {
        let title = R.string.localizable.scamWarningAlertTitle(
            chainAsset.asset.symbol.uppercased(),
            preferredLanguages: selectedLocale.rLanguages
        )
        let message = R.string.localizable.scamWarningAlertSubtitle(
            chainAsset.asset.symbolUppercased,
            preferredLanguages: selectedLocale.rLanguages
        )

        let sheetViewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            icon: R.image.iconWarningBig()
        )
        wireframe.present(
            viewModel: sheetViewModel,
            from: view
        )
    }

    func setup() {
        interactor.setup()
        provideViewModel()
        loadingCollector.utilityBalanceReady = chainAsset.isUtility
    }

    func didTapBackButton() {
        wireframe.close(view: view)
    }

    func didTapConfirmButton() {
        switch call {
        case .transfer:
            validateAndSubmitTransfer()
        case .xorlessTransfer:
            submitXorlessTransfer()
        }
    }
}

extension WalletSendConfirmPresenter: WalletSendConfirmInteractorOutputProtocol {
    func didTransfer(result: Result<String, Error>) {
        view?.didStopLoading()

        switch result {
        case let .success(hash):

            wireframe.complete(on: view, title: hash, chainAsset: chainAsset)
        case let .failure(error):
            guard let view = view else {
                return
            }

            if let rpcError = error as? RPCResponse<EthereumData>.Error, rpcError.code == -32000 {
                wireframe.presentAmountTooHigh(from: view, locale: selectedLocale)
                return
            }

            if !wireframe.present(error: error, from: view, locale: selectedLocale) {
                wireframe.presentExtrinsicFailed(from: view, locale: selectedLocale)
            }
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            if chainAsset == self.chainAsset {
                loadingCollector.balanceReady = true
                checkLoadingState()

                balance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? 0.0

                provideViewModel()
            } else if let utilityAsset = interactor.getFeePaymentChainAsset(for: chainAsset),
                      utilityAsset == chainAsset {
                loadingCollector.utilityBalanceReady = true
                checkLoadingState()

                utilityBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(self.chainAsset.asset.precision)
                    )
                } ?? 0
            }
        case let .failure(error):
            logger?.error("Did receive account info error: \(error)")
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumBalance):
            loadingCollector.edReady = true
            checkLoadingState()
            self.minimumBalance = minimumBalance

            provideViewModel()
        case let .failure(error):
            loadingCollector.edReady = true
            checkLoadingState()
            logger?.error("Did receive minimum balance error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>, for priceId: AssetModel.PriceId?) {
        switch result {
        case let .success(priceData):
            if chainAsset.asset.priceId == priceId {
                self.priceData = priceData
                let utilityChainAsset = interactor.getFeePaymentChainAsset(for: chainAsset)
                if utilityChainAsset?.chainAssetId == chainAsset.chainAssetId {
                    utilityPriceData = priceData
                }
            } else {
                utilityPriceData = priceData
            }
            provideViewModel()
        case let .failure(error):
            logger?.error("Did receive price error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            guard let utilityAsset = interactor.getFeePaymentChainAsset(for: chainAsset) else { return }
            fee = BigUInt(string: dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: Int16(utilityAsset.asset.precision))
            } ?? nil
            updateFeeViewModel()
            provideViewModel()
            let amount = Decimal.fromSubstrateAmount(call.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
            let tipPaymentChainAsset = interactor.getFeePaymentChainAsset(for: chainAsset)
            let tipPaymentPrecision = tipPaymentChainAsset?.asset.precision ?? chainAsset.asset.precision
            let tip = Decimal.fromSubstrateAmount(call.tip ?? .zero, precision: Int16(tipPaymentPrecision)) ?? .zero

            let fullAmount = amount + fee.or(.zero) + tip
            interactor.fetchEquilibriumTotalBalance(chainAsset: chainAsset, amount: fullAmount)
            loadingCollector.feeReady = true
            checkLoadingState()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceive(eqTotalBalance: Decimal) {
        eqUilibriumTotalBalance = eqTotalBalance
        loadingCollector.balanceReady = true
        checkLoadingState()
    }
}

extension WalletSendConfirmPresenter: Localizable {
    func applyLocalization() {}
}
