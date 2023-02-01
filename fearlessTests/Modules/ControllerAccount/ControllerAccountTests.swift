import XCTest
import Cuckoo
import RobinHood
import FearlessUtils
import SoraKeystore
import SoraFoundation
@testable import fearless
import BigInt

class ControllerAccountTests: XCTestCase {

    func testContinueAction() {
        let wireframe = MockControllerAccountWireframeProtocol()
        let interactor = MockControllerAccountInteractorInputProtocol()
        let viewModelFactory = MockControllerAccountViewModelFactoryProtocol()
        let view = MockControllerAccountViewProtocol()
        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let chain = ChainModelGenerator.generateChain(generatingAssets: 1,
                                                      addressPrefix: UInt16(SNAddressType.genericSubstrate.rawValue))
        let asset = ChainModelGenerator.generateAssetWithId("test", symbol: "test")
        let selectedAccount = AccountGenerator.generateMetaAccount()
        let presenter = ControllerAccountPresenter(wireframe: wireframe,
                                                   interactor: interactor,
                                                   viewModelFactory: viewModelFactory,
                                                   applicationConfig: ApplicationConfig.shared,
                                                   chain: chain,
                                                   asset: asset,
                                                   selectedAccount: selectedAccount,
                                                   dataValidatingFactory: dataValidatingFactory,
                                                   logger: Logger.shared)

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
            when(stub).showConfirmation(from: any(),
                                        controllerAccountItem: any(),
                                        asset: any(), chain: any(),
                                        selectedAccount: any()).then { _ in
                showConfirmationExpectation.fulfill()
            }
            
            when(stub).present(viewModel: any(), from: any()).thenDoNothing()
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

        let chainAccountItem = ChainAccountResponse(chainId: chain.chainId,
                                                    accountId: selectedAccount.substrateAccountId,
                                                    publicKey: selectedAccount.substratePublicKey,
                                                    name: "test",
                                                    cryptoType: .ecdsa,
                                                    addressPrefix: 0,
                                                    isEthereumBased: false,
                                                    isChainAccount: false,
                                                    walletId: selectedAccount.metaId)
        presenter.didReceiveControllerAccount(result: .success(chainAccountItem))

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

        let feeDetails = FeeDetails(
            baseFee: BigUInt(stringLiteral: "12600002654"),
            lenFee: BigUInt(stringLiteral: "0"),
            adjustedWeightFee: BigUInt(stringLiteral: "331759000")
        )
        let fee = RuntimeDispatchInfo(inclusionFee: feeDetails)
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
            when(stub).present(message: any(), title: any(), closeAction: any(), from: any(), actions: any()).then { _ in
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
        let extraFee = RuntimeDispatchInfo(inclusionFee: feeDetails)
        presenter.didReceiveFee(result: .success(extraFee))

        // when
        presenter.proceed()

        // then
        wait(for: [showErrorAlertExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
