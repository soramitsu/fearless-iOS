import Foundation
import SSFUtils

final class YourValidatorListPoolViewModelFactory {
    private let balanceViewModeFactory: BalanceViewModelFactoryProtocol

    init(
        balanceViewModeFactory: BalanceViewModelFactoryProtocol
    ) {
        self.balanceViewModeFactory = balanceViewModeFactory
    }

    private func createValidatorViewModel(
        for model: SelectedValidatorInfo,
        apyFormatter: NumberFormatter,
        locale: Locale
    ) throws -> YourValidatorViewModel {
        let amountTitle: String? = {
            guard case let .active(allocation) = model.myNomination else {
                return nil
            }

            return balanceViewModeFactory.amountFromValue(allocation.amount, usageCase: .listCrypto).value(for: locale)
        }()

        let apy: NSAttributedString? = model.stakeInfo.map { info in
            let stakeReturnString = apyFormatter.stringFromDecimal(info.stakeReturn) ?? ""
            let apyString = "APY \(stakeReturnString)"

            let apyStringAttributed = NSMutableAttributedString(string: apyString)
            apyStringAttributed.addAttribute(
                .foregroundColor,
                value: R.color.colorColdGreen() as Any,
                range: (apyString as NSString).range(of: stakeReturnString)
            )
            return apyStringAttributed
        }

        let stakedString = R.string.localizable.yourValidatorsValidatorTotalStake(
            "\(model.totalStake)",
            preferredLanguages: locale.rLanguages
        )

        return YourValidatorViewModel(
            address: model.address,
            name: model.identity?.displayName,
            amount: amountTitle,
            apy: apy,
            staked: stakedString,
            shouldHaveWarning: model.oversubscribed,
            shouldHaveError: model.hasSlashes
        )
    }

    private func createSectionsFromOrder(
        _ order: [YourValidatorListSectionStatus],
        mapping: [YourValidatorListSectionStatus: [YourValidatorViewModel]]
    ) -> [YourValidatorListSection] {
        order.compactMap { status in
            if let validators = mapping[status], !validators.isEmpty {
                return YourValidatorListSection(status: status, validators: validators)
            } else {
                return nil
            }
        }
    }
}

extension YourValidatorListPoolViewModelFactory: YourValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: YourValidatorListViewModelState,
        locale: Locale
    ) -> YourValidatorListViewModel? {
        guard let relaychainViewModelState = viewModelState as? YourValidatorListPoolViewModelState,
              let model = relaychainViewModelState.validatorsModel else {
            return nil
        }

        let apyFormatter = NumberFormatter.percent

        let validatorsMapping = model.allValidators
            .sorted(by: { $0.stakeReturn > $1.stakeReturn })
            .reduce(
                into: [YourValidatorListSectionStatus: [YourValidatorViewModel]]()) { result, item in
                let sectionStatus: YourValidatorListSectionStatus = {
                    guard let modelStatus = item.myNomination else {
                        return .pending
                    }

                    switch modelStatus {
                    case .active:
                        return .stakeAllocated
                    case .elected:
                        return .stakeNotAllocated
                    case .unelected:
                        return .unelected
                    }
                }()

                guard let viewModel = try? createValidatorViewModel(
                    for: item,
                    apyFormatter: apyFormatter,
                    locale: locale
                ) else {
                    return
                }

                result[sectionStatus] = (result[sectionStatus] ?? []) + [viewModel]
            }

        let sectionsOrder: [YourValidatorListSectionStatus] = [
            .stakeAllocated, .pending, .stakeNotAllocated, .unelected
        ]

        let sections = createSectionsFromOrder(sectionsOrder, mapping: validatorsMapping)
        let activeAllocations: [ValidatorTokenAllocation] = model.allValidators.compactMap { validator in
            if case let .active(allocation) = validator.myNomination {
                return allocation
            } else {
                return nil
            }
        }

        let allValidatorsWithoutReward = !activeAllocations.isEmpty &&
            activeAllocations.allSatisfy { !$0.isRewarded }

        return YourValidatorListViewModel(
            allValidatorWithoutRewards: allValidatorsWithoutReward,
            sections: sections,
            userCanSelectValidators: relaychainViewModelState.selectValidatorsStartFlow() != nil
        )
    }
}
