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

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let primitiveFactory = WalletPrimitiveFactory(keystore: keychain, settings: settings)

        let view = MockValidatorInfoViewProtocol()
        let wireframe = MockValidatorInfoWireframeProtocol()
        let interactor = ValidatorInfoInteractor(validatorInfo: validator)

        let addressType = SNAddressType.kusamaMain
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        let validatorInfoViewModelFactory = ValidatorInfoViewModelFactory(
            iconGenerator: PolkadotIconGenerator(),
            asset: asset,
            amountFormatterFactory: AmountFormatterFactory())

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
            when(stub).didReceive(accountViewModel: any(), extrasViewModel: any()).then { viewModels in
                XCTAssertEqual(self.validator.address, viewModels.0.address)
                expectation.fulfill()
            }
        }

        interactor.setup()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
}
