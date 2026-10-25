import Foundation
import SoraFoundation
import SSFModels
import SSFUtils
import SSFQRService

protocol ReceiveAndRequestAssetViewInput: ControllerBackedProtocol {
    func didStartQRGeneration()
    func didReceive(viewModel: ReceiveAssetViewModel)
    func didReceive(image: UIImage)
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?)
    func didReceive(amountInputViewModel: IAmountInputViewModel?)
}

protocol ReceiveAndRequestAssetInteractorInput: AnyObject {
    func setup(with output: ReceiveAndRequestAssetInteractorOutput)
}

final class ReceiveAndRequestAssetPresenter {
    enum Constants {
        static let qrSize = CGSize(width: 240, height: 240)
    }

    // MARK: Private properties

    private weak var view: ReceiveAndRequestAssetViewInput?
    private let router: ReceiveAndRequestAssetRouterInput
    private let interactor: ReceiveAndRequestAssetInteractorInput

    private let wallet: MetaAccountModel
    private var chainAsset: ChainAsset
    private let qrService: QRService
    private let sharingFactory: AccountShareFactoryProtocol

    private var qrOperation: Task<UIImage?, Error>?
    private var qrGeneration = UUID()
    private var currentQRImage: UIImage?
    private var isClosed = false
    private var inputResult: AmountInputResult?
    private var accountInfos: [ChainAssetKey: AccountInfo?] = [:]

    private var address: String? {
        UniversalWalletAccountAddressResolver.address(for: chainAsset.chain, wallet: wallet)
    }

    // MARK: - Constructors

    init(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        qrService: QRService,
        sharingFactory: AccountShareFactoryProtocol,
        interactor: ReceiveAndRequestAssetInteractorInput,
        router: ReceiveAndRequestAssetRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.wallet = wallet
        self.qrService = qrService
        self.sharingFactory = sharingFactory
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        guard let address = address else {
            assertionFailure()
            return
        }

        view?.didReceive(viewModel: ReceiveAssetViewModel(
            asset: chainAsset.asset.symbolUppercased,
            networkName: chainAsset.chain.name,
            accountName: wallet.name,
            address: address,
            isSora: chainAsset.chain.isSora
        ))
    }

    private func provideAssetVewModel() {
        let balance = getBalance()
        let inputAmount = inputResult?.absoluteValue(from: balance) ?? 0.0
        let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, chainAsset: chainAsset)

        let priceData = AssetTrustResolver.displayPrice(for: chainAsset, currency: wallet.selectedCurrency)

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)
        view?.didReceive(assetBalanceViewModel: viewModel)
    }

    func provideInputViewModel() {
        let balance = getBalance()
        let inputAmount = inputResult?.absoluteValue(from: balance)

        let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, chainAsset: chainAsset)
        let inputViewModel = balanceViewModelFactory.createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)
        view?.didReceive(amountInputViewModel: inputViewModel)
    }

    private func getBalance() -> Decimal {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return .zero
        }
        let key = chainAsset.uniqueKey(accountId: accountId)
        guard let accountInfo = accountInfos[key] else {
            return .zero
        }
        let balance = accountInfo.map {
            Decimal.fromSubstrateAmount(
                $0.data.sendAvailable,
                precision: Int16(chainAsset.asset.precision)
            ) ?? .zero
        } ?? .zero
        return balance
    }

    private func buildBalanceViewModelFactory(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> BalanceViewModelFactoryProtocol {
        let assetInfo = chainAsset.asset
            .displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )
        return balanceViewModelFactory
    }

    private func generateQR() {
        cancelQRGeneration()
        guard !isClosed else { return }
        view?.didStartQRGeneration()

        // Freeze the account, asset and amount before asynchronous work begins.
        let qrType: QRType
        do {
            qrType = try makeQRType()
        } catch {
            processOperation(result: .failure(error))
            return
        }
        let generation = qrGeneration
        let service = qrService
        qrOperation = Task { [weak self] in
            let result: Result<UIImage, Error>
            do {
                try Task.checkCancellation()
                result = .success(try await service.generate(with: qrType, qrSize: Constants.qrSize))
            } catch {
                result = .failure(error)
            }
            await MainActor.run { [weak self] in
                guard !Task.isCancelled, let self, self.qrGeneration == generation, !self.isClosed else {
                    return
                }
                self.qrOperation = nil
                self.processOperation(result: result)
            }
            return try? result.get()
        }
    }

    private func makeQRType() throws -> QRType {
        guard let address else { throw ChainAccountFetchingError.accountNotExists }
        guard chainAsset.chain.isSora else { return .address(address) }
        guard let account = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            throw ChainAccountFetchingError.accountNotExists
        }
        let balance = getBalance()
        var inputAmount = inputResult?.absoluteValue(from: balance).stringWithPointSeparator
        if
            chainAsset.asset.currencyId == BokoloConstants.bokoloCashAssetCurrencyId,
            var input = inputResult?.absoluteValue(from: balance) {
            var drounded = Decimal()
            NSDecimalRound(&drounded, &input, 2, .plain)
            inputAmount = drounded.stringWithPointSeparator
        }
        return .addressInfo(SoraQRInfo(
            prefix: SubstrateQRConstants.prefix,
            address: address,
            rawPublicKey: account.publicKey,
            username: wallet.name,
            assetId: chainAsset.asset.currencyId ?? "",
            amount: inputAmount
        ))
    }

    private func cancelQRGeneration() {
        qrGeneration = UUID()
        qrOperation?.cancel()
        qrOperation = nil
        currentQRImage = nil
    }

    private func processOperation(result: Result<UIImage, Error>) {
        switch result {
        case let .success(image):
            currentQRImage = image
            view?.didReceive(image: image)
        case let .failure(error):
            router.present(error: error, from: view, locale: selectedLocale)
        }
    }
}

// MARK: - ReceiveAndRequestAssetViewOutput

extension ReceiveAndRequestAssetPresenter: ReceiveAndRequestAssetViewOutput {
    func didTapSelectAsset() {
        router.showSelectAsset(
            from: view,
            wallet: wallet,
            selectedAssetId: chainAsset.asset.id,
            chainAssets: chainAsset.chain.chainAssets,
            output: self
        )
    }

    func didLoad(view: ReceiveAndRequestAssetViewInput) {
        isClosed = false
        self.view = view
        interactor.setup(with: self)

        provideViewModel()
        generateQR()
        if chainAsset.chain.isSora {
            provideAssetVewModel()
            provideInputViewModel()
        } else {
            view.didReceive(assetBalanceViewModel: nil)
        }
    }

    func share(qrImage: UIImage) {
        guard !isClosed, currentQRImage === qrImage else { return }
        guard let address = address else {
            assertionFailure()
            return
        }

        let sources = sharingFactory.createSources(
            accountAddress: address,
            qrImage: qrImage,
            assetSymbol: chainAsset.asset.symbolUppercased,
            chainName: chainAsset.chain.name,
            locale: selectedLocale
        )

        router.share(sources: sources, from: view, with: nil)
    }

    func close() {
        isClosed = true
        cancelQRGeneration()
        view?.didStartQRGeneration()
        router.dismiss(view: view)
    }

    func presentAccountOptions() {
        guard let address = address, let view = view else {
            return
        }

        router.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))
        provideAssetVewModel()
        generateQR()
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)
        provideAssetVewModel()
        generateQR()
    }
}

// MARK: - ReceiveAndRequestAssetInteractorOutput

extension ReceiveAndRequestAssetPresenter: ReceiveAndRequestAssetInteractorOutput {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: SSFModels.ChainAsset) {
        switch result {
        case let .success(accountInfo):
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }
            let key = chainAsset.uniqueKey(accountId: accountId)
            let previousAmount = inputResult?.absoluteValue(from: getBalance())
            accountInfos[key] = accountInfo
            if self.chainAsset == chainAsset {
                provideAssetVewModel()
                provideInputViewModel()
                if case .rate? = inputResult,
                   previousAmount != inputResult?.absoluteValue(from: getBalance()) {
                    generateQR()
                }
            }
        case let .failure(failure):
            Logger.shared.customError(failure)
        }
    }
}

// MARK: - Localizable

extension ReceiveAndRequestAssetPresenter: Localizable {
    func applyLocalization() {}
}

extension ReceiveAndRequestAssetPresenter: ReceiveAndRequestAssetModuleInput {}

extension ReceiveAndRequestAssetPresenter: SelectAssetModuleOutput {
    func assetSelection(didCompleteWith chainAsset: SSFModels.ChainAsset?, contextTag _: Int?) {
        guard let chainAsset = chainAsset else {
            return
        }
        self.chainAsset = chainAsset

        provideViewModel()
        provideAssetVewModel()
        provideInputViewModel()
        generateQR()
    }
}
