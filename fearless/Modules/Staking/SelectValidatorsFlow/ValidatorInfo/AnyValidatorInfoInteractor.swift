final class AnyValidatorInfoInteractor: ValidatorInfoInteractorBase {
    private let validatorInfo: ValidatorInfoProtocol

    init(
        validatorInfo: ValidatorInfoProtocol,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        walletAssetId: WalletAssetId
    ) {
        self.validatorInfo = validatorInfo
        super.init(
            singleValueProviderFactory: singleValueProviderFactory,
            walletAssetId: walletAssetId
        )
    }

    override func setup() {
        super.setup()
        presenter?.didReceive(validatorInfo: validatorInfo)
    }
}
