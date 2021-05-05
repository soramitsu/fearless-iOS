import XCTest
@testable import fearless
import Cuckoo
import SoraKeystore
import IrohaCrypto
import FearlessUtils

class ValidatorInfoTests: XCTestCase {
    let validator = SelectedValidatorInfo(address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6")

    func testSetup() {
        // given
        let chain = Chain.westend

        let settings = InMemorySettingsManager()
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let view = MockValidatorInfoViewProtocol()
        let wireframe = MockValidatorInfoWireframeProtocol()

        let priceProvider = SingleValueProviderFactoryStub.westendNominatorStub().price
        let interactor = ValidatorInfoInteractor(validatorInfo: validator, priceProvider: priceProvider)

        let addressType = SNAddressType.kusamaMain
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let validatorInfoViewModelFactory = ValidatorInfoViewModelFactory(
            iconGenerator: PolkadotIconGenerator(),
            asset: asset,
            amountFormatterFactory: AmountFormatterFactory(),
            balanceViewModelFactory: balanceViewModelFactory)

        let presenter = ValidatorInfoPresenter(viewModelFactory: validatorInfoViewModelFactory,
                                               asset: asset,
                                               locale: Locale.current)

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        // when

        let expectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didRecieve(any()).then { _ in
                expectation.fulfill()
            }
        }

        interactor.setup()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
}
