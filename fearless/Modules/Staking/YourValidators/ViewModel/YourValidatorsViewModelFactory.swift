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
            shouldHaveWarning: model.stakeInfo?.oversubscribed ?? false,
            shouldHaveError: model.slashed
        )
    }

    private func createTitle(
        for sectionStatus: YourValidatorsSectionStatus,
        count: Int
    ) -> LocalizableResource<String>? {
        guard sectionStatus != .stakeNotAllocated else {
            return nil
        }

        return LocalizableResource { locale in
            let formatter = NumberFormatter.quantity.localizableResource()
            let localizedFormatter = formatter.value(for: locale)
            let countString = localizedFormatter.string(from: NSNumber(value: count)) ?? "0"

            switch sectionStatus {
            case .stakeAllocated:
                return R.string.localizable.stakingYourActiveFormat(
                    countString,
                    preferredLanguages: locale.rLanguages
                )

            case .inactive:
                return R.string.localizable.stakingYourInactiveFormat(
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

            default:
                return ""
            }
        }
    }

    private func createDescription(
        for sectionStatus: YourValidatorsSectionStatus
    ) -> LocalizableResource<String>? {
        LocalizableResource { locale in
            switch sectionStatus {
            case .stakeAllocated:
                return R.string.localizable.stakingYourAllocatedDescription(
                    preferredLanguages: locale.rLanguages
                )
            case .stakeNotAllocated:
                return R.string.localizable.stakingYourNotAllocatedDescription(
                    preferredLanguages: locale.rLanguages
                )
            case .inactive:
                return R.string.localizable.stakingYourInactiveDescription(
                    preferredLanguages: locale.rLanguages
                )
            case .pending:
                return R.string.localizable.stakingYourValidatorsChangingTitle(
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
                let title: LocalizableResource<String>? = {
                    let validatorsCount: Int = {
                        if status == .stakeAllocated {
                            return validators.count + (mapping[.stakeNotAllocated]?.count ?? 0)
                        }
                        return mapping[status]?.count ?? 0
                    }()

                    return createTitle(for: status, count: validatorsCount)
                }()
                let description = createDescription(for: status)
                return YourValidatorsSection(
                    status: status,
                    title: title,
                    description: description,
                    validators: validators
                )
            } else {
                return nil
            }
        }
    }
}

extension YourValidatorsViewModelFactory: YourValidatorsViewModelFactoryProtocol {
    func createViewModel(for model: YourValidatorsModel) throws -> [YourValidatorsSection] {
        let validatorsMapping = model.allValidators.reduce(
            into: [YourValidatorsSectionStatus: [YourValidatorViewModel]]()) { result, item in
            let sectionStatus: YourValidatorsSectionStatus = {
                guard let modelStatus = item.myNomination else {
                    return .pending
                }

                switch modelStatus {
                case .active:
                    return .stakeAllocated
                case .elected:
                    return .stakeNotAllocated
                case .unelected:
                    return .inactive
                }
            }()

            guard let viewModel = try? createValidatorViewModel(for: item) else {
                return
            }

            result[sectionStatus] = (result[sectionStatus] ?? []) + [viewModel]
        }

        let sectionsOrder: [YourValidatorsSectionStatus] = [
            .stakeAllocated, .pending, .stakeNotAllocated, .inactive
        ]

        return createSectionsFromOrder(sectionsOrder, mapping: validatorsMapping)
    }
}
