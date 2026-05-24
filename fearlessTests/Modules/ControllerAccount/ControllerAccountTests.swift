import XCTest
import Cuckoo
import RobinHood
import SSFUtils
import SSFModels
import FearlessSecureStorage
import FearlessFoundation
@testable import fearless
import BigInt

class ControllerAccountTests: XCTestCase {

    func testBalanceViewModelFactory_whenInjectedEventCenterPublishesMetaAccountChange_thenUpdatesCurrency() {
        let asset = ChainModelGenerator.generateAssetWithId("xor", symbol: "XOR")
        let selectedAccount = AccountGenerator.generateMetaAccount().replacingCurrency(.defaultCurrency())
        let eventCenter = StakingFormatterEventCenterSpy()
        let factory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            selectedMetaAccount: selectedAccount,
            eventCenter: eventCenter
        )

        let priceData = PriceData(
            currencyId: Currency.defaultCurrency().id,
            priceId: "xor",
            price: "2",
            fiatDayChange: nil,
            coingeckoPriceId: nil
        )
        let locale = Locale(identifier: "en_US")

        let usdPrice = factory.priceFromAmount(3, priceData: priceData).value(for: locale)
        eventCenter.notify(with: MetaAccountModelChangedEvent(account: selectedAccount.replacingCurrency(.euro())))
        let euroPrice = factory.priceFromAmount(3, priceData: priceData).value(for: locale)

        XCTAssertEqual(eventCenter.addedObservers.count, 1)
        XCTAssertTrue(usdPrice.contains(Currency.defaultCurrency().symbol))
        XCTAssertTrue(euroPrice.contains(Currency.euro().symbol))
    }

    func testRewardViewModelFactory_whenInjectedEventCenterPublishesMetaAccountChange_thenUpdatesCurrency() {
        let asset = ChainModelGenerator.generateAssetWithId("xor", symbol: "XOR")
        let selectedAccount = AccountGenerator.generateMetaAccount().replacingCurrency(.defaultCurrency())
        let eventCenter = StakingFormatterEventCenterSpy()
        let factory = RewardViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            selectedMetaAccount: selectedAccount,
            eventCenter: eventCenter
        )

        let priceData = PriceData(
            currencyId: Currency.defaultCurrency().id,
            priceId: "xor",
            price: "2",
            fiatDayChange: nil,
            coingeckoPriceId: nil
        )
        let locale = Locale(identifier: "en_US")

        let usdReward = factory.createRewardViewModel(
            reward: 3,
            targetReturn: 0.1,
            priceData: priceData
        ).value(for: locale)
        eventCenter.notify(with: MetaAccountModelChangedEvent(account: selectedAccount.replacingCurrency(.euro())))
        let euroReward = factory.createRewardViewModel(
            reward: 3,
            targetReturn: 0.1,
            priceData: priceData
        ).value(for: locale)

        XCTAssertEqual(eventCenter.addedObservers.count, 1)
        XCTAssertTrue(usdReward.price?.contains(Currency.defaultCurrency().symbol) == true)
        XCTAssertTrue(euroReward.price?.contains(Currency.euro().symbol) == true)
    }

    func testContinueAction() throws {
        let wireframe = MockControllerAccountWireframeProtocol()
        let interactor = MockControllerAccountInteractorInputProtocol()
        let viewModelFactory = MockControllerAccountViewModelFactoryProtocol()
        let view = MockControllerAccountViewProtocol()
        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let chain = ChainModelGenerator.generateChain(generatingAssets: 1,
                                                      addressPrefix: UInt16(fearless.SNAddressType.genericSubstrate.rawValue))
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
            when(stub.localizationManager.get).thenReturn(LocalizationManager.shared)
            when(stub.controller.get).thenReturn(UIViewController())
            when(stub.didReceive(feeViewModel: any(LocalizableResource<BalanceViewModelProtocol>.self))).thenDoNothing()
        }

        // given
        let showConfirmationExpectation = XCTestExpectation(
            description: "Show Confirmation screen if user has sufficient balance to pay fee"
        )
        stub(wireframe) { stub in
            when(
                stub.showConfirmation(
                    from: any(ControllerBackedProtocol?.self),
                    controllerAccountItem: any(fearless.ChainAccountResponse.self),
                    asset: any(SSFModels.AssetModel.self),
                    chain: any(SSFModels.ChainModel.self),
                    selectedAccount: any(fearless.MetaAccountModel.self)
                )
            ).then { _ in
                showConfirmationExpectation.fulfill()
            }

            when(stub.present(viewModel: any(SheetAlertPresentableViewModel.self), from: any(ControllerBackedProtocol?.self))).thenDoNothing()
        }
        stub(viewModelFactory) { stub in
            when(
                stub.createViewModel(
                    stashItem: any(StashItem.self),
                    stashAccountItem: any(fearless.ChainAccountResponse?.self),
                    chosenAccountItem: any(fearless.ChainAccountResponse?.self),
                    chainAsset: any(SSFModels.ChainAsset.self)
                )
            ).then { _ in
                ControllerAccountViewModel(
                    chainAsset: SSFModels.ChainAsset(chain: chain, asset: asset),
                    stashViewModel: .init(closure: { _ in AccountInfoViewModel(title: "", address: "", name: "", icon: nil)}),
                    controllerViewModel: .init(closure: { _ in AccountInfoViewModel(title: "", address: "", name: "", icon: nil)}),
                    currentAccountIsController: false,
                    actionButtonIsEnabled: true
                )
            }
        }
        stub(view) { stub in
            when(stub.reload(with: any())).thenDoNothing()
        }

        let chainAccountItem = fearless.ChainAccountResponse(chainId: chain.chainId,
                                                    accountId: selectedAccount.substrateAccountId,
                                                    publicKey: selectedAccount.substratePublicKey,
                                                    name: "test",
                                                    cryptoType: .ecdsa,
                                                    addressPrefix: chain.addressPrefix,
                                                    isEthereumBased: false,
                                                    isChainAccount: false,
                                                    walletId: selectedAccount.metaId)
        let chosenControllerAddress = try XCTUnwrap(chainAccountItem.toAddress())
        let stashMetaAccount = AccountGenerator.generateMetaAccount()
        let stashAccountItem = fearless.ChainAccountResponse(chainId: chain.chainId,
                                                    accountId: stashMetaAccount.substrateAccountId,
                                                    publicKey: stashMetaAccount.substratePublicKey,
                                                    name: "stash",
                                                    cryptoType: .ecdsa,
                                                    addressPrefix: chain.addressPrefix,
                                                    isEthereumBased: false,
                                                    isChainAccount: false,
                                                    walletId: stashMetaAccount.metaId)
        let stashAddress = try XCTUnwrap(stashAccountItem.toAddress())

        let stashItem = StashItem(stash: stashAddress, controller: "currentControllerAddress")
        presenter.didReceiveStashItem(result: Result.success(stashItem))
        presenter.didReceiveControllerAccount(result: Result.success(chainAccountItem))

        let controllerAccountInfo = AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: 100000000000000, reserved: 0, frozen: 0, flags: 0)
        )
        presenter.didReceiveAccountInfo(result: Result.success(controllerAccountInfo), address: chosenControllerAddress)

        let stashAccountInfo = AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: 100000000000000, reserved: 0, frozen: 0, flags: 0)
        )
        presenter.didReceiveAccountInfo(result: Result<AccountInfo?, Error>.success(stashAccountInfo), address: stashAddress)

        let feeValue = BigUInt(stringLiteral: "12600002654")
        let fee = RuntimeDispatchInfo(feeValue: feeValue)
        presenter.didReceiveFee(result: Result.success(fee))

        // when
        presenter.proceed()

        // then
        wait(for: [showConfirmationExpectation], timeout: Constants.defaultExpectationDuration)

    }
}

private final class StakingFormatterEventCenterSpy: EventCenterProtocol {
    private(set) var addedObservers: [EventVisitorProtocol] = []

    func notify(with event: EventProtocol) {
        addedObservers.forEach { event.accept(visitor: $0) }
    }

    func add(observer: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {
        addedObservers.append(observer)
    }

    func remove(observer: EventVisitorProtocol) {
        addedObservers.removeAll { $0 === observer }
    }
}
