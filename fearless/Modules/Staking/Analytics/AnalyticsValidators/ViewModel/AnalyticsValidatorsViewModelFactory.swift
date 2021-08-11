import SoraFoundation
import FearlessUtils

final class AnalyticsValidatorsViewModelFactory: AnalyticsValidatorsViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()

    func createViewModel(
        eraValidatorInfos: [SQEraValidatorInfo],
        identitiesByAddress: [AccountAddress: AccountIdentity]?,
        page: AnalyticsValidatorsPage
    ) -> LocalizableResource<AnalyticsValidatorsViewModel> {
        LocalizableResource { locale in
            let totalEras = self.totalErasCount(eraValidatorInfos: eraValidatorInfos)

            let distinctValidators = Set<String>(eraValidatorInfos.map(\.address))

            let validators: [AnalyticsValidatorItemViewModel] = distinctValidators.map { address in

                let icon = try? self.iconGenerator.generateFromAddress(address)
                let validatorName = (identitiesByAddress?[address]?.displayName) ?? address
                let progressText: String = {
                    switch page {
                    case .activity:
                        let infos = eraValidatorInfos.filter { $0.address == address }
                        let distinctEras = Set<EraIndex>(infos.map(\.era))
                        let distinctErasCount = distinctEras.count

                        let percents = Int(Double(distinctErasCount) / Double(totalEras) * 100.0)
                        return "\(percents)% (\(distinctErasCount) eras)"
                    case .rewards:
                        return "0 KSM"
                    }
                }()

                return .init(
                    icon: icon,
                    validatorName: validatorName,
                    progress: 0.29,
                    progressText: progressText,
                    validatorAddress: address
                )
            }
            let chartData = ChartData(amounts: [1, 2], xAxisValues: ["a", "b"])
            let listTitle = self.determineListTitle(page: page, locale: locale)
            return AnalyticsValidatorsViewModel(
                chartData: chartData,
                listTitle: listTitle,
                validators: validators,
                selectedPage: page
            )
        }
    }

    private func determineListTitle(page: AnalyticsValidatorsPage, locale _: Locale) -> String {
        switch page {
        case .activity:
            return "stake allocation".uppercased()
        case .rewards:
            return "Rewards".uppercased()
        }
    }

    func totalErasCount(eraValidatorInfos: [SQEraValidatorInfo]) -> Int {
        let distinctEras = Set<EraIndex>(eraValidatorInfos.map(\.era))
        return distinctEras.count
    }

    func progressDescription(
        page: AnalyticsValidatorsPage,
        validatorInfo: SQEraValidatorInfo,
        totalErasCount: Int,
        locale: Locale
    ) -> String {
        switch page {
        case .activity:
            return progressDescriptionStake(
                validatorInfo: validatorInfo,
                totalErasCount: totalErasCount,
                locale: locale
            )
        case .rewards:
            return "0 KSM"
        }
    }

    func progressDescriptionStake(
        validatorInfo _: SQEraValidatorInfo,
        totalErasCount: Int,
        locale _: Locale
    ) -> String {
        "(\(totalErasCount) eras)"
    }
}
