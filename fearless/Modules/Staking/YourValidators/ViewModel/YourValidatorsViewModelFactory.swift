import Foundation
import FearlessUtils
import SoraFoundation

protocol YourValidatorsViewModelFactoryProtocol {
    func createViewModel(for model: YourValidatorsModel) throws -> [YourValidatorsSection]
}

final class YourValidatorsViewModelFactory {
    let balanceViewModeFactory: BalanceViewModelFactoryProtocol

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(balanceViewModeFactory: BalanceViewModelFactoryProtocol) {
        self.balanceViewModeFactory = balanceViewModeFactory
    }

    private func createValidatorViewModel(
        for model: SelectedValidatorInfo
    ) throws -> YourValidatorViewModel {
        let icon = try iconGenerator.generateFromAddress(model.address)

        let amountTitle: LocalizableResource<String>? = {
            guard case let .active(amount) = model.myNomination else {
                return nil
            }

            return balanceViewModeFactory.amountFromValue(amount)
        }()

        return YourValidatorViewModel(
            address: model.address,
            icon: icon,
            name: model.identity?.displayName,
            amount: amountTitle,
            shouldHaveWarning: model.stakeInfo?.oversubscribed ?? false
        )
    }

    private func createTitle(
        for sectionStatus: YourValidatorsSectionStatus,
        count: Int
    ) -> LocalizableResource<String> {
        let formatter = NumberFormatter.quantity.localizableResource()

        return LocalizableResource { locale in
            let localizedFormatter = formatter.value(for: locale)
            let countString = localizedFormatter.string(from: NSNumber(value: count)) ?? "0"

            switch sectionStatus {
            case .active:
                return R.string.localizable.stakingYourActiveFormat(
                    countString,
                    preferredLanguages: locale.rLanguages
                )
            case .inactive:
                return R.string.localizable.stakingYourInactiveFormat(
                    countString,
                    preferredLanguages: locale.rLanguages
                )
            case .waiting:
                return R.string.localizable.stakingYourWaitingFormat(
                    countString,
                    preferredLanguages: locale.rLanguages
                )
            case .slashed:
                return R.string.localizable.stakingYourSlashedFormat(
                    countString,
                    preferredLanguages: locale.rLanguages
                )
            case .pending:
                let maxCountString = localizedFormatter
                    .string(from: NSNumber(value: StakingConstants.maxTargets)) ?? "0"
                return R.string.localizable.stakingYourPendingFormat(
                    countString,
                    maxCountString,
                    preferredLanguages: locale.rLanguages
                )
            }
        }
    }

    private func createSectionsFromOrder(
        _ order: [YourValidatorsSectionStatus],
        mapping: [YourValidatorsSectionStatus: [YourValidatorViewModel]]
    ) -> [YourValidatorsSection] {
        order.compactMap { status in
            if let validators = mapping[status], !validators.isEmpty {
                let title = createTitle(for: status, count: validators.count)
                return YourValidatorsSection(
                    status: status,
                    title: title, validators: validators
                )
            } else {
                return nil
            }
        }
    }
}

extension YourValidatorsViewModelFactory: YourValidatorsViewModelFactoryProtocol {
    func createViewModel(for model: YourValidatorsModel) throws -> [YourValidatorsSection] {
        let allValidatos = model.currentValidators + model.pendingValidators
        let validatorsMapping = allValidatos.reduce(
            into: [YourValidatorsSectionStatus: [YourValidatorViewModel]]()) { result, item in
            let sectionStatus: YourValidatorsSectionStatus = {
                if let modelStatus = item.myNomination {
                    return YourValidatorsSectionStatus(modelStatus: modelStatus)
                } else {
                    return .pending
                }
            }()

            guard let viewModel = try? createValidatorViewModel(for: item) else {
                return
            }

            result[sectionStatus] = (result[sectionStatus] ?? []) + [viewModel]
        }

        let sectionsOrder: [YourValidatorsSectionStatus] = [
            .active, .slashed, .pending, .inactive, .waiting
        ]

        return createSectionsFromOrder(sectionsOrder, mapping: validatorsMapping)
    }
}
