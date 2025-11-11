import XCTest
import Cuckoo
import RobinHood
import SSFUtils
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
        let balanceFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            selectedMetaAccount: selectedAccount
        )
        let presenter = ControllerAccountPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            applicationConfig: ApplicationConfig.shared,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            dataValidatingFactory: dataValidatingFactory,
            logger: Logger.shared,
            balanceViewModelFactory: balanceFactory
        )

        presenter.view = view
        dataValidatingFactory.view = view

        stub(view) { stub in
            when(stub).localizationManager.get.thenReturn(LocalizationManager.shared)
        }

        // given
        let showConfirmationExpectation = XCTestExpectation(
            description: "Show Confirmation screen if user has sufficient balance to pay fee"
        )
        stub(wireframe) { stub in
            when(stub).showConfirmation(
                from: any(ControllerBackedProtocol?.self),
                controllerAccountItem: any(fearless.ChainAccountResponse.self),
                asset: any(AssetModel.self),
                chain: any(ChainModel.self),
                selectedAccount: any(fearless.MetaAccountModel.self)
            ).then { _ in
                showConfirmationExpectation.fulfill()
            }
            
            when(stub).present(viewModel: any(), from: any()).thenDoNothing()
        }
        stub(viewModelFactory) { stub in
            when(stub).createViewModel(
                stashItem: any(StashItem.self),
                stashAccountItem: any(fearless.ChainAccountResponse?.self),
                chosenAccountItem: any(fearless.ChainAccountResponse?.self)
            ).then { _ in ControllerAccountViewModel(
                chainAsset: SSFModels.ChainAsset(chain: chain, asset: asset),
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
        presenter.didReceiveStashItem(result: Result.success(stashItem))

        let chainAccountItem = ChainAccountResponse(chainId: chain.chainId,
                                                    accountId: selectedAccount.substrateAccountId,
                                                    publicKey: selectedAccount.substratePublicKey,
                                                    name: "test",
                                                    cryptoType: .ecdsa,
                                                    addressPrefix: 0,
                                                    isEthereumBased: false,
                                                    isChainAccount: false,
                                                    walletId: selectedAccount.metaId)
        presenter.didReceiveControllerAccount(result: Result.success(chainAccountItem))

        let controllerAccountInfo = AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: 100000000000000, reserved: 0, frozen: 0, flags: 0)
        )
        presenter.didReceiveAccountInfo(result: Result.success(controllerAccountInfo), address: controllerAddress)

        let stashAccountInfo = AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: 100000000000000, reserved: 0, frozen: 0, flags: 0)
        )
        presenter.didReceiveAccountInfo(result: .success(stashAccountInfo), address: stashAddress)

        let feeValue = BigUInt(stringLiteral: "12600002654")
        let fee = RuntimeDispatchInfo(feeValue: feeValue)
        presenter.didReceiveFee(result: Result.success(fee))

        // when
        presenter.proceed()

        // then
        wait(for: [showConfirmationExpectation], timeout: Constants.defaultExpectationDuration)


        // otherwise
        let showErrorAlertExpectation = XCTestExpectation(
            description: "Show error alert if user has not sufficient balance to pay fee"
        )
        stub(wireframe) { stub in
            when(stub).present(
                message: any(String.self),
                title: any(String?.self),
                closeAction: any(String.self),
                from: any(ControllerBackedProtocol?.self),
                actions: any([UIAlertAction].self)
            ).then { _ in
                showErrorAlertExpectation.fulfill()
            }
        }

        let accountInfoSmallBalance = AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: 10, reserved: 0, frozen: 0, flags: 0)
        )
        presenter.didReceiveAccountInfo(result: Result.success(accountInfoSmallBalance), address: stashAddress)
        let extraFee = RuntimeDispatchInfo(feeValue: feeValue)
        presenter.didReceiveFee(result: Result.success(extraFee))

        // when
        presenter.proceed()

        // then
        wait(for: [showErrorAlertExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
