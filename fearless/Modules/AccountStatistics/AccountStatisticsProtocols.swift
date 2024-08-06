typealias AccountStatisticsModuleCreationResult = (
    view: AccountStatisticsViewInput,
    input: AccountStatisticsModuleInput
)

protocol AccountStatisticsRouterInput: AnyObject, AnyDismissable, ApplicationStatusPresentable {}

protocol AccountStatisticsModuleInput: AnyObject {}

protocol AccountStatisticsModuleOutput: AnyObject {}
