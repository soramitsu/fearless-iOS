import SoraFoundation
import FearlessUtils

final class AnalyticsValidatorsViewModelFactory: AnalyticsValidatorsViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()

    func createViewModel() -> LocalizableResource<AnalyticsValidatorsViewModel> {
        LocalizableResource { _ in
            let validators: [AnalyticsValidatorItemViewModel] = (0 ... 20).map { _ in
                let address = "5GNy7frYA4BwWpKwxKAFWt4eBsZ9oAvXrp9SyDj6qzJAaNzB"
                let icon = try? self.iconGenerator.generateFromAddress(address)
                return .init(
                    icon: icon,
                    validatorName: "✨👍✨ Day7 ✨👍✨",
                    progress: 0.29,
                    progressText: "29% (25 eras)",
                    validatorAddress: address
                )
            }
            let chartData = ChartData(amounts: [1, 2], xAxisValues: ["a", "b"])
            return AnalyticsValidatorsViewModel(chartData: chartData, validators: validators)
        }
    }
}
