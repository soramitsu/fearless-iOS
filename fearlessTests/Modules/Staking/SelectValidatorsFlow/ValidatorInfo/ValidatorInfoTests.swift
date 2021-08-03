import XCTest
@testable import fearless
import Cuckoo
import SoraKeystore
import IrohaCrypto
import FearlessUtils
import SoraFoundation

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

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let validatorInfoViewModelFactory = ValidatorInfoViewModelFactory(
            iconGenerator: PolkadotIconGenerator(),
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = ValidatorInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: validatorInfoViewModelFactory,
            chain: chain,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let expectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didRecieve(viewModel: any()).then { _ in
                expectation.fulfill()
            }
        }

        interactor.setup()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
}
