import Foundation
import IrohaCrypto
import FearlessUtils

final class StakingRewardDetailsPresenter {
    weak var view: StakingRewardDetailsViewProtocol?
    var wireframe: StakingRewardDetailsWireframeProtocol!
    var interactor: StakingRewardDetailsInteractorInputProtocol!

    private let chain: Chain
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let addressFactory = SS58AddressFactory()
    private let validatorAddress: String?
    private let payoutInfo: PayoutInfo
    private let activeEra: EraIndex
    private let iconGenerator: IconGenerating

    init(
        payoutInfo: PayoutInfo,
        activeEra: EraIndex,
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        iconGenerator: IconGenerating
    ) {
        self.payoutInfo = payoutInfo
        self.activeEra = activeEra
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
        self.iconGenerator = iconGenerator
        validatorAddress = try? addressFactory.addressFromAccountId(
            data: payoutInfo.validator,
            type: chain.addressType
        )
    }

    private func createViewModel() -> StakingRewardDetailsViewModel {
        let dateText = formattedDateText(payoutEra: payoutInfo.era, activeEra: activeEra, chain: chain)
        let validatorIcon = getValidatorIcon(validatorAddress: validatorAddress)

        let rows: [RewardDetailsRow] = [
            .validatorInfo(.init(
                name: "Validator",
                address: addressTitle(payoutInfo),
                icon: validatorIcon
            )),
            .date(.init(
                titleText: R.string.localizable.stakingRewardDetailsDate(),
                valueText: dateText
            )),
            .era(.init(
                titleText: R.string.localizable.stakingRewardDetailsEra(),
                valueText: "#\(payoutInfo.era.description)"
            )),
            .reward(.init(ksmAmountText: tokenAmountText(payoutInfo.reward), usdAmountText: "$0"))
        ]
        return .init(rows: rows)
    }

    private func addressTitle(_ payout: PayoutInfo) -> String {
        if let displayName = payout.identity?.displayName {
            return displayName
        }

        if let address = try? addressFactory
            .addressFromAccountId(data: payout.validator, type: chain.addressType) {
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

    private func formattedDateText(payoutEra: EraIndex, activeEra: EraIndex, chain: Chain) -> String {
        let pastDays = (activeEra - payoutEra) / UInt32(chain.erasPerDay)
        guard let daysAgo = Calendar.current
            .date(byAdding: .day, value: -Int(pastDays), to: Date())
        else { return "" }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"

        return dateFormatter.string(from: daysAgo)
    }

    private func getValidatorIcon(validatorAddress: String?) -> UIImage? {
        guard let address = validatorAddress else { return nil }
        return try? iconGenerator.generateFromAddress(address)
            .imageWithFillColor(
                .white,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )
    }
}

extension StakingRewardDetailsPresenter: StakingRewardDetailsPresenterProtocol {
    func setup() {
        let viewModel = createViewModel()
        view?.reload(with: viewModel)
    }

    func handlePayoutAction() {
        wireframe.showPayoutConfirmation(from: view)
    }

    func handleValidatorAccountAction() {
        guard
            let view = view,
            let address = validatorAddress
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
