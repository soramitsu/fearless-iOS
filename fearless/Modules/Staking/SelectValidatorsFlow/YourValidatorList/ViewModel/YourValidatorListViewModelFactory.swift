import Foundation
import FearlessUtils
import SoraFoundation

protocol YourValidatorListViewModelFactoryProtocol {
    func createViewModel(for model: YourValidatorsModel, locale: Locale) throws -> YourValidatorListViewModel
}

final class YourValidatorListViewModelFactory {
    let balanceViewModeFactory: BalanceViewModelFactoryProtocol

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(balanceViewModeFactory: BalanceViewModelFactoryProtocol) {
        self.balanceViewModeFactory = balanceViewModeFactory
    }

    private func createValidatorViewModel(
        for model: SelectedValidatorInfo,
        apyFormatter: NumberFormatter,
        locale: Locale
    ) throws -> YourValidatorViewModel {
        let icon = try iconGenerator.generateFromAddress(model.address)

        let amountTitle: String? = {
            guard case let .active(amount) = model.myNomination else {
                return nil
            }

            return balanceViewModeFactory.amountFromValue(amount).value(for: locale)
        }()

        let apy: String? = model.stakeInfo.map { info in
            apyFormatter.stringFromDecimal(info.stakeReturn) ?? ""
        }

        return YourValidatorViewModel(
            address: model.address,
            icon: icon,
            name: model.identity?.displayName,
            amount: amountTitle,
            apy: apy,
            shouldHaveWarning: model.stakeInfo?.oversubscribed ?? false,
            shouldHaveError: model.hasSlashes
        )
    }

    private func createSectionsFromOrder(
        _ order: [YourValidatorListSectionStatus],
        mapping: [YourValidatorListSectionStatus: [YourValidatorViewModel]]
    ) -> YourValidatorListViewModel {
        let sections: [YourValidatorListSection] = order.compactMap { status in
            if let validators = mapping[status], !validators.isEmpty {
                return YourValidatorListSection(status: status, validators: validators)
            } else {
                return nil
            }
        }

        return YourValidatorListViewModel(hasValidatorWithoutRewards: true, sections: sections)
    }
}

extension YourValidatorListViewModelFactory: YourValidatorListViewModelFactoryProtocol {
    func createViewModel(for model: YourValidatorsModel, locale: Locale) throws -> YourValidatorListViewModel {
        let apyFormatter = NumberFormatter.percentSingle

        let validatorsMapping = model.allValidators.reduce(
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

        return createSectionsFromOrder(sectionsOrder, mapping: validatorsMapping)
    }
}
