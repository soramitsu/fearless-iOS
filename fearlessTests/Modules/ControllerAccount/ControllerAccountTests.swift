import XCTest
import Cuckoo
import RobinHood
import FearlessUtils
import SoraKeystore
import SoraFoundation
@testable import fearless

class ControllerAccountTests: XCTestCase {

    func testContinueAction() {
        let wireframe = MockControllerAccountWireframeProtocol()
        let interactor = MockControllerAccountInteractorInputProtocol()
        let viewModelFactory = MockControllerAccountViewModelFactoryProtocol()
        let view = MockControllerAccountViewProtocol()
        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = ControllerAccountPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            applicationConfig: ApplicationConfig.shared,
            chain: .westend,
            dataValidatingFactory: dataValidatingFactory
        )
        presenter.view = view
        dataValidatingFactory.view = view

        stub(view) { stub in
            when(stub).localizationManager.get.then { LocalizationManager.shared }
        }

        // given
        let showConfirmationExpectation = XCTestExpectation(
            description: "Show Confirmation screen if user has sufficient balance to pay fee"
        )
        stub(wireframe) { stub in
            when(stub).showConfirmation(from: any(), controllerAccountItem: any()).then { _ in
                showConfirmationExpectation.fulfill()
            }
        }
        stub(viewModelFactory) { stub in
            when(stub).createViewModel(stashItem: any(), stashAccountItem: any(), chosenAccountItem: any())
                .then { _ in ControllerAccountViewModel(
                    stashViewModel: .init(closure: { _ in AccountInfoViewModel(title: "", address: "", name: "", icon: nil)}),
                    controllerViewModel: .init(closure: { _ in AccountInfoViewModel(title: "", address: "", name: "", icon: nil)}),
                    currentAccountIsController: false,
                    actionButtonIsEnabled: true
                )}
        }
        stub(view) { stub in
            when(stub).reload(with: any()).thenDoNothing()
        }

        let controllerAddress = "controllerAddress"
        let stashAddress = "stashAddress"

        let stashItem = StashItem(stash: stashAddress, controller: controllerAddress)
        presenter.didReceiveStashItem(result: .success(stashItem))

        let accountItem = AccountItem(address: controllerAddress, cryptoType: .ecdsa, username: "usename", publicKeyData: Data())
        presenter.didReceiveControllerAccount(result: .success(accountItem))

        let controllerAccountInfo = AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: 100000000000000, reserved: 0, miscFrozen: 0, feeFrozen: 0)
        )
        presenter.didReceiveAccountInfo(result: .success(controllerAccountInfo), address: controllerAddress)

        let stashAccountInfo = AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: 100000000000000, reserved: 0, miscFrozen: 0, feeFrozen: 0)
        )
        presenter.didReceiveAccountInfo(result: .success(stashAccountInfo), address: stashAddress)

        let fee = RuntimeDispatchInfo(dispatchClass: "normal", fee: "12600002654", weight: 331759000)
        presenter.didReceiveFee(result: .success(fee))

        // when
        presenter.proceed()

        // then
        wait(for: [showConfirmationExpectation], timeout: Constants.defaultExpectationDuration)


        // otherwise
        let showErrorAlertExpectation = XCTestExpectation(
            description: "Show error alert if user has not sufficient balance to pay fee"
        )
        stub(wireframe) { stub in
            when(stub).present(message: any(), title: any(), closeAction: any(), from: any()).then { _ in
                showErrorAlertExpectation.fulfill()
            }
        }

        let accountInfoSmallBalance = AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: 10, reserved: 0, miscFrozen: 0, feeFrozen: 0)
        )
        presenter.didReceiveAccountInfo(result: .success(accountInfoSmallBalance), address: stashAddress)

        let extraFee = RuntimeDispatchInfo(dispatchClass: "normal", fee: "126000002654", weight: 331759000)
        presenter.didReceiveFee(result: .success(extraFee))

        // when
        presenter.proceed()

        // then
        wait(for: [showErrorAlertExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
