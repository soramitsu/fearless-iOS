import Foundation
import IrohaCrypto

final class StakingRewardDetailsPresenter {
    weak var view: StakingRewardDetailsViewProtocol?
    var wireframe: StakingRewardDetailsWireframeProtocol!
    var interactor: StakingRewardDetailsInteractorInputProtocol!

    private let chain: Chain
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let addressFactory = SS58AddressFactory()
    private let payoutInfo: PayoutInfo
    private let activeEra: EraIndex

    init(
        payoutInfo: PayoutInfo,
        activeEra: EraIndex,
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.payoutInfo = payoutInfo
        self.activeEra = activeEra
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    private func createViewModel() -> StakingRewardDetailsViewModel {
        let dateText = formattedDateText(payoutEra: payoutInfo.era, activeEra: activeEra, chain: chain)
        let rows: [RewardDetailsRow] = [
            .validatorInfo(.init(
                name: "Validator",
                address: addressTitle(payoutInfo.validator),
                icon: R.image.iconAccount()
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

    private func addressTitle(_ accountId: Data) -> String {
        if let address = try? addressFactory.addressFromAccountId(data: accountId, type: chain.addressType) {
            return address
        }
        return ""
    }

    private func tokenAmountText(_ value: Decimal) -> String {
        balanceViewModelFactory.amountFromValue(value).value(for: .autoupdatingCurrent)
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
            let address = try? addressFactory.addressFromAccountId(
                data: payoutInfo.validator, type: chain.addressType
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
