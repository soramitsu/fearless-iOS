import Foundation
import IrohaCrypto

final class StakingRewardDetailsPresenter {
    weak var view: StakingRewardDetailsViewProtocol?
    var wireframe: StakingRewardDetailsWireframeProtocol!
    var interactor: StakingRewardDetailsInteractorInputProtocol!

    private let chain: Chain
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let addressFactory = SS58AddressFactory()
    private let payoutItem: PayoutInfo

    init(
        payoutItem: PayoutInfo,
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.payoutItem = payoutItem
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    private func createViewModel(payoutItem: PayoutInfo) -> StakingRewardDetailsViewModel {
        let rows: [RewardDetailsRow] = [
            .validatorInfo(.init(
                name: "Validator",
                address: addressTitle(payoutItem.validator),
                icon: R.image.iconAccount()
            )),
            .date(.init(
                titleText: R.string.localizable.stakingRewardDetailsDate(),
                valueText: "Feb 2, 2021"
            )),
            .era(.init(
                titleText: R.string.localizable.stakingRewardDetailsEra(),
                valueText: "#\(payoutItem.era.description)"
            )),
            .reward(.init(ksmAmountText: tokenAmountText(payoutItem.reward), usdAmountText: "$0"))
        ]
        return .init(rows: rows)
    }

    private func addressTitle(_ accountId: Data) -> String {
        if let address = try? addressFactory.addressFromAccountId(data: accountId, type: chain.addressType) {
            return address
        }
        return ""
    }

    private func tokenAmountText(_ value: Decimal) -> String {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        return balanceViewModelFactory.amountFromValue(value).value(for: locale)
    }

    private func priceText(_ amount: Decimal, priceData: PriceData?) -> String {
        guard let priceData = priceData else {
            return ""
        }

        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        let price = balanceViewModelFactory
            .priceFromAmount(amount, priceData: priceData).value(for: locale)
        return price
    }
}

extension StakingRewardDetailsPresenter: StakingRewardDetailsPresenterProtocol {
    func setup() {
        let viewModel = createViewModel(payoutItem: payoutItem)
        view?.reload(with: viewModel)
    }

    func handlePayoutAction() {
        wireframe.showPayoutConfirmation(from: view)
    }

    func handleValidatorAccountAction() {
        guard
            let view = view,
            let address = try? addressFactory.addressFromAccountId(
                data: payoutItem.validator, type: chain.addressType
            )
        else { return }
        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: .autoupdatingCurrent
        )
    }
}

extension StakingRewardDetailsPresenter: StakingRewardDetailsInteractorOutputProtocol {}
