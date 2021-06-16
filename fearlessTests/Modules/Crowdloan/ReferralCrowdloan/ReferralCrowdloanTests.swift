import XCTest
@testable import fearless
import SoraKeystore
import Cuckoo
import SoraFoundation

class ReferralCrowdloanTests: XCTestCase {

    let displayInfo = CrowdloanDisplayInfo(
        paraid: "2000",
        name: "Karura",
        token: "KAR",
        description: "Some description",
        website: "http://google.com",
        icon: "http://google.com/icon.svg",
        rewardRate: 12.0,
        customFlow: .karura
    )

    func testReferralInputSuccess() throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let chain = Chain.westend

        let expectedCode = KaruraBonusService.defaultReferralCode

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            networkType: chain,
                                                            keychain: keychain,
                                                            settings: settings)

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let addressType = settings.selectedConnection.type
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        let amountFormatterFactory = AmountFormatterFactory()

        let crowdloanViewModelFactory = CrowdloanContributionViewModelFactory(
            amountFormatterFactory: amountFormatterFactory,
            chainDateCalculator: ChainDateCalculator(),
            asset: asset
        )

        let view = MockReferralCrowdloanViewProtocol()
        let wireframe = MockReferralCrowdloanWireframeProtocol()

        let delegate = MockCustomCrowdloanDelegate()
        let bonusService = CrowdloanBonusServiceStub()

        let presenter = ReferralCrowdloanPresenter(
            wireframe: wireframe,
            bonusService: bonusService,
            displayInfo: displayInfo,
            inputAmount: 10,
            crowdloanDelegate: delegate,
            crowdloanViewModelFactory: crowdloanViewModelFactory,
            defaultReferralCode: KaruraBonusService.defaultReferralCode,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        let inputViewModelReceived = XCTestExpectation()
        let learnMoreReceived = XCTestExpectation()
        let referralReceived = XCTestExpectation()

        stub(view) { stub in
            when(stub).didStartLoading().thenDoNothing()
            when(stub).didStopLoading().thenDoNothing()
            when(stub).isSetup.get.thenReturn(true, false)

            when(stub).didReceiveInput(viewModel: any()).then { _ in
                inputViewModelReceived.fulfill()
            }

            when(stub).didReceiveLearnMore(viewModel: any()).then { _ in
                learnMoreReceived.fulfill()
            }

            when(stub).didReceiveReferral(viewModel: any()).then { _ in
                referralReceived.fulfill()
            }
        }

        presenter.setup()

        wait(for: [inputViewModelReceived, learnMoreReceived, referralReceived], timeout: 10.0)

        // when

        var actualCode: String? = nil

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.complete(on: any())).then { _ in
                completionExpectation.fulfill()
            }
        }

        stub(delegate) { stub in
            when(stub).didReceive(bonusService: any()).then { service in
                actualCode = service.referralCode
            }
        }

        // first input some code
        presenter.update(referralCode: "0xaaabbbbccc")

        // then ask to put default one
        presenter.applyDefaultCode()

        // agree with terms
        presenter.setTermsAgreed(value: true)

        // finalize
        presenter.applyInputCode()

        wait(for: [completionExpectation], timeout: 10.0)

        // then

        XCTAssertEqual(expectedCode, actualCode)
    }
}
