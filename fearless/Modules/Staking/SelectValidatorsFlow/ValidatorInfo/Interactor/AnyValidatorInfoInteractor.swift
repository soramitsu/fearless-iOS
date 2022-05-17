final class AnyValidatorInfoInteractor: ValidatorInfoInteractorBase {
    private let validatorInfo: ValidatorInfoProtocol

    init(
        validatorInfo: ValidatorInfoProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        asset: AssetModel
    ) {
        self.validatorInfo = validatorInfo
        super.init(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            asset: asset
        )
    }

    override func setup() {
        super.setup()
        presenter?.didReceiveValidatorInfo(result: .success(validatorInfo))
    }

    override func reload() {
        super.reload()
        presenter?.didReceiveValidatorInfo(result: .success(validatorInfo))
    }
}
