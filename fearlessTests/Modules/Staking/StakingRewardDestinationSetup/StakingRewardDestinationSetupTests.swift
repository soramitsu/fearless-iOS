//
//  StakingRewardDestinationSetupTests.swift
//  fearlessTests
//
//  Created by Ruslan Rezin on 18.05.2021.
//  Copyright © 2021 Soramitsu. All rights reserved.
//

import XCTest
@testable import fearless
import Cuckoo
import RobinHood
import FearlessUtils
import SoraKeystore
import SoraFoundation

class StakingRewardDestinationSetupTests: XCTestCase {

    func testRewardDestinationSetupSuccess() throws {
        // given

        let view = MockStakingRewardDestSetupViewProtocol()
        let wireframe = MockStakingRewardDestSetupWireframeProtocol()

        let newPayoutAccount = AccountItem(address: "5Gh52T8TzDekJsosRp22SQ4uyGi8MfuwL8qMBJ1ASF1P8r8i",
                                           cryptoType: .sr25519,
                                           username: "new payout",
                                           publicKeyData: Data(repeating: 0, count: 32)
        )

        // when

        let presenter = try setupPresenter(for: view, wireframe: wireframe, newPayout: newPayoutAccount)

        let changesApplied = XCTestExpectation()

        // after changes from restake to payout and after account selection
        changesApplied.expectedFulfillmentCount = 2

        stub(view) { stub in
            when(stub).didReceiveRewardDestination(viewModel: any()).then { viewModel in
                if let viewModel = viewModel, viewModel.canApply {
                    changesApplied.fulfill()
                }
            }

            when(stub).localizationManager.get.then { nil }

            when(stub).didReceiveFee(viewModel: any()).thenDoNothing()
        }

        let payoutSelectionsExpectation = XCTestExpectation()
        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).presentAccountSelection(
                any(),
                selectedAccountItem: any(),
                title: any(),
                delegate: any(),
                from: any(),
                context: any()
            ).then { (accounts, _, _, delegate, _, context) in
                if let index = accounts.firstIndex(where: { $0.address == newPayoutAccount.address }) {
                    delegate.modalPickerDidSelectModelAtIndex(index, context: context)

                    payoutSelectionsExpectation.fulfill()
                } else {
                    delegate.modalPickerDidCancel(context: context)
                }
            }

            when(stub).proceed(view: any(), rewardDestination: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        presenter.selectPayoutDestination()
        presenter.selectPayoutAccount()

        wait(for: [changesApplied, payoutSelectionsExpectation], timeout: 10.0)

        presenter.proceed()

        // then

        wait(for: [completionExpectation], timeout: 10.0)
    }

    private func setupPresenter(
        for view: MockStakingRewardDestSetupViewProtocol,
        wireframe: MockStakingRewardDestSetupWireframeProtocol,
        newPayout: AccountItem?
    ) throws -> StakingRewardDestSetupPresenter {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let chain = Chain.westend
        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            networkType: chain,
                                                            keychain: keychain,
                                                            settings: settings)

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let assetId = WalletAssetId(
            rawValue: primitiveFactory.createAssetForAddressType(chain.addressType).identifier
        )!

        let storageFacade = SubstrateStorageTestFacade()
        let operationManager = OperationManager()

        let nominatorAddress = settings.selectedAccount!.address
        let cryptoType = settings.selectedAccount!.cryptoType

        let singleValueProviderFactory = SingleValueProviderFactoryStub.westendNominatorStub()

        // save stash item

        let stashItem = StashItem(stash: nominatorAddress, controller: nominatorAddress)
        let repository: CoreDataRepository<StashItem, CDStashItem> =
            storageFacade.createRepository()

        let operationQueue = OperationQueue()
        let saveStashItemOperation = repository.saveOperation({ [stashItem] }, { [] })
        operationQueue.addOperations([saveStashItemOperation], waitUntilFinished: true)

        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager
        )

        let runtimeCodingService = try RuntimeCodingServiceStub.createWestendService()

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageTestFacade().createRepository()
        let anyAccountRepository = AnyDataProviderRepository(accountRepository)

        let calculatorService = RewardCalculatorServiceStub(engine: WestendStub.rewardCalculator)

        // save controller and payout
        let controllerItem = settings.selectedAccount!
        let saveControllerOperation = anyAccountRepository
            .saveOperation({
                if let payout = newPayout {
                    return [controllerItem, payout]
                } else {
                    return [controllerItem]
                }
            }, { [] })
        operationQueue.addOperations([saveControllerOperation], waitUntilFinished: true)

        let extrinsicServiceFactory = ExtrinsicServiceFactoryStub(
            extrinsicService: ExtrinsicServiceStub.dummy(),
            signingWraper: try DummySigner(cryptoType: cryptoType)
        )

        let interactor = StakingRewardDestSetupInteractor(
            selectedAccountAddress: controllerItem.address,
            singleValueProviderFactory: singleValueProviderFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            substrateProviderFactory: substrateProviderFactory,
            calculatorService: calculatorService,
            runtimeService: runtimeCodingService,
            operationManager: operationManager,
            accountRepository: anyAccountRepository,
            feeProxy: ExtrinsicFeeProxy(),
            assetId: assetId,
            chain: chain
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let viewModelFactory = RewardDestinationViewModelFactory(balanceViewModelFactory: balanceViewModelFactory)

        let presenter = StakingRewardDestSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            rewardDestViewModelFactory: viewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            applicationConfig: ApplicationConfig.shared,
            chain: chain
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let rewardDestinationExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceiveFee(viewModel: any()).then { feeViewModel in
                if feeViewModel != nil {
                    feeExpectation.fulfill()
                }
            }

            when(stub).didReceiveRewardDestination(viewModel: any()).then { viewModel in
                if let viewModel = viewModel, !viewModel.canApply {
                    rewardDestinationExpectation.fulfill()
                }
            }
        }

        presenter.setup()

        // then

        wait(for: [feeExpectation, rewardDestinationExpectation], timeout: 10)

        return presenter
    }

}
