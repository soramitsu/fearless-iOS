import XCTest
import Cuckoo
import RobinHood
import SoraFoundation
import CommonWallet
import IrohaCrypto
@testable import fearless

class StakingBondMoreTests: XCTestCase {

    func testContinueAction() throws {
        let wireframe = MockStakingBondMoreWireframeProtocol()
        let interactor = MockStakingBondMoreInteractorInputProtocol()
        let balanceViewModelFactory = StubBalanceViewModelFactory()
        let stubAsset = WalletAsset(
            identifier: "",
            name: .init(closure: { _ in "" }),
            symbol: "",
            precision: 0
        )

        let dataValidator = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidator,
            asset: stubAsset
        )

        let view = MockStakingBondMoreViewProtocol()
        presenter.view = view
        dataValidator.view = view

        stub(view) { stub in
            when(stub).localizationManager.get.then { _ in nil }
            when(stub).didReceiveInput(viewModel: any()).thenDoNothing()
            when(stub).didReceiveFee(viewModel: any()).thenDoNothing()
            when(stub).didReceiveAsset(viewModel: any()).thenDoNothing()
        }

        // given
        let continueExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).showConfirmation(from: any(), amount: any()).then { _ in
                continueExpectation.fulfill()
            }
        }

        // balance & fee is received
        let accountInfo = AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: 100000000000000, reserved: 0, miscFrozen: 0, feeFrozen: 0)
        )

        presenter.didReceiveAccountInfo(result: .success(accountInfo))

        let paymentInfo = RuntimeDispatchInfo(dispatchClass: "normal", fee: "12600002654", weight: 331759000)
        presenter.didReceiveFee(result: .success(paymentInfo))

        let stashItem = StashItem(stash: WestendStub.address, controller: WestendStub.address)
        presenter.didReceiveStashItem(result: .success(stashItem))

        let publicKeyData = try SS58AddressFactory().accountId(from: stashItem.stash)
        let stashAccount = AccountItem(
            address: stashItem.stash,
            cryptoType: .sr25519,
            username: "test",
            publicKeyData: publicKeyData
        )

        presenter.didReceiveStash(result: .success(stashAccount))

        // when

        presenter.updateAmount(0.1)
        presenter.handleContinueAction()

        // then
        wait(for: [continueExpectation], timeout: Constants.defaultExpectationDuration)

        // given
        let errorAlertExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).present(message: any(), title: any(), closeAction: any(), from: any()).then { _ in
                errorAlertExpectation.fulfill()
            }
        }
        // empty balance & extra fee is received
        presenter.didReceiveAccountInfo(result: .success(nil))
        let paymentInfoWithExtraFee = RuntimeDispatchInfo(dispatchClass: "normal", fee: "12600000000002654", weight: 331759000)
        presenter.didReceiveFee(result: .success(paymentInfoWithExtraFee))

        // when
        presenter.handleContinueAction()

        // then
        wait(for: [errorAlertExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
