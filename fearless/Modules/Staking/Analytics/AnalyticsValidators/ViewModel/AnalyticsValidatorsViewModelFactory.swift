import SoraFoundation
import FearlessUtils

final class AnalyticsValidatorsViewModelFactory: AnalyticsValidatorsViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()

    func createViewModel(
        eraValidatorInfos: [SQEraValidatorInfo],
        identitiesByAddress: [AccountAddress: AccountIdentity]?,
        page: AnalyticsValidatorsPage
    ) -> LocalizableResource<AnalyticsValidatorsViewModel> {
        LocalizableResource { _ in
            let validators: [AnalyticsValidatorItemViewModel] = eraValidatorInfos.map { info in
                let address = info.address
                let icon = try? self.iconGenerator.generateFromAddress(address)
                let validatorName = (identitiesByAddress?[address]?.displayName) ?? address

                return .init(
                    icon: icon,
                    validatorName: validatorName,
                    progress: 0.29,
                    progressText: "29% (25 eras)",
                    validatorAddress: address
                )
            }
            let chartData = ChartData(amounts: [1, 2], xAxisValues: ["a", "b"])
            return AnalyticsValidatorsViewModel(chartData: chartData, validators: validators, selectedPage: page)
        }
    }
}
