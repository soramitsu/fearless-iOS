import Foundation

final class BalanceInfoRouter: BalanceInfoRouterInput {
    func presentLockedInfo(
        from view: ControllerBackedProtocol?,
        balanceContext: BalanceContext,
        info: AssetBalanceDisplayInfo,
        currency: Currency
    ) {
        let balanceLocksController = ModalInfoFactory.createFromBalanceContext(
            balanceContext,
            amountFormatter: AssetBalanceFormatterFactory().createDisplayFormatter(for: info),
            precision: info.assetPrecision,
            currency: currency
        )
        view?.controller.present(balanceLocksController, animated: true)
    }
}
