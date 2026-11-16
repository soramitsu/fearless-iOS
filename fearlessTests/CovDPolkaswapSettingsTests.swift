import Foundation
import SoraFoundation
import SoraKeystore
import UIKit
import XCTest

@testable import fearless

final class CovDSettingsOutputSpy: PolkaswapTransaktionSettingsModuleOutput, SelectMarketModuleOutput, PolkaswapDisclaimerModuleOutput {
    private(set) var received: [(LiquiditySourceType, Float)] = []
    private(set) var selectedMarkets: [LiquiditySourceType] = []
    private(set) var disclaimerReads = 0

    func didReceive(market: LiquiditySourceType, slippadgeTolerance: Float) { received.append((market, slippadgeTolerance)) }
    func didSelect(market: LiquiditySourceType) { selectedMarkets.append(market) }
    func disclaimerDidRead() { disclaimerReads += 1 }
}

final class CovDDisclaimerRouterSpy: PolkaswapDisclaimerRouterInput {
    private(set) var dismissCount = 0
    private(set) var webURLs: [URL] = []

    func dismiss(view _: ControllerBackedProtocol?) { dismissCount += 1 }
    func showWeb(url: URL, from _: ControllerBackedProtocol, style _: WebPresentableStyle) { webURLs.append(url) }
}

final class CovDPolkaswapSettingsTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    func testSlippageFactoryWarnsForTooLowAndFrontrunValues() {
        let factory = SlippageToleranceViewModelFactory()
        let locale = Locale(identifier: "en_US")
        let low = factory.buildViewModel(with: 0.05, locale: locale)
        XCTAssertEqual(low.textFieldText, "0.05%")
        XCTAssertFalse(low.labelAttributedString?.string.isEmpty ?? true)
        let normal = factory.buildViewModel(with: 0.5, locale: locale)
        XCTAssertEqual(normal.textFieldText, "0.5%")
        XCTAssertNil(normal.labelAttributedString)
        let frontrun = factory.buildViewModel(with: 7, locale: locale)
        XCTAssertNotNil(frontrun.labelAttributedString)
        XCTAssertNotEqual(frontrun.labelAttributedString?.string, low.labelAttributedString?.string)
        let capped = factory.buildViewModel(with: 25, locale: locale)
        XCTAssertEqual(capped.value, 10)
        XCTAssertEqual(capped.textFieldText, "10%")
    }

    func testSettingsScreenChangesSlippageResetsAndSaves() throws {
        let output = CovDSettingsOutputSpy()
        let module = try XCTUnwrap(PolkaswapTransaktionSettingsAssembly.configureModule(
            markets: [.smart, .xyk, .tbc], selectedMarket: .xyk, slippadgeTolerance: 1, moduleOutput: output
        ))
        let controller = try XCTUnwrap(module.view.controller as? PolkaswapTransaktionSettingsViewController)
        controller.modalPresentationStyle = .fullScreen
        window = try CovDFixtures.host(controller)
        let layout = controller.rootView
        XCTAssertEqual(layout.slippageToleranceView.textField.text, "1%")
        XCTAssertEqual(layout.slippageToleranceSlider.value, 1)

        layout.slippageToleranceSlider.value = 7
        layout.slippageToleranceSlider.sendActions(for: .valueChanged)
        XCTAssertEqual(layout.slippageToleranceView.textField.text, "7%")
        XCTAssertFalse(layout.slippageToleranceWarningLabel.attributedText?.string.isEmpty ?? true)

        layout.revertButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(layout.slippageToleranceView.textField.text, "0.5%")
        let presenter = try XCTUnwrap(module.input as? PolkaswapTransaktionSettingsPresenter)
        presenter.didSelect(market: .tbc)
        presenter.didChangeSlider(value: 2)
        layout.saveButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.received.count, 1)
        XCTAssertEqual(output.received.first?.0, .tbc)
        XCTAssertEqual(output.received.first?.1, 2)
        layout.backButton.sendActions(for: .touchUpInside)
        controller.applyLocalization()
        presenter.applyLocalization()

        layout.selectMarketView.sendActions(for: .touchUpInside)
        XCTAssertTrue(CovDFixtures.spin { controller.presentedViewController is SelectMarketViewController })
        let selectMarket = try XCTUnwrap(controller.presentedViewController as? SelectMarketViewController)
        XCTAssertEqual(selectMarket.rootView.tableView.numberOfRows(inSection: 0), 3)
        selectMarket.loadViewIfNeeded()
        XCTAssertFalse(selectMarket.rootView.titleLabel.text?.isEmpty ?? true)
    }

    func testSelectMarketPresenterListsDescriptionsTogglesAndSelects() throws {
        let output = CovDSettingsOutputSpy()
        let module = try XCTUnwrap(SelectMarketAssembly.configureModule(markets: [.smart, .xyk], moduleOutput: output))
        let controller = try XCTUnwrap(module.view.controller as? SelectMarketViewController)
        window = try CovDFixtures.host(controller)
        let presenter = try XCTUnwrap(module.input as? SelectMarketPresenter)
        XCTAssertEqual(presenter.numberOfItems, 2)
        let first = try XCTUnwrap(presenter.item(at: 0) as? SelectableSubtitleListViewModel)
        XCTAssertEqual(first.title, LiquiditySourceType.smart.name)
        XCTAssertFalse(first.isExpand)
        presenter.didTapAdditionalButton(at: IndexPath(row: 0, section: 0))
        XCTAssertTrue(first.isExpand)
        presenter.selectItem(at: 5)
        XCTAssertTrue(output.selectedMarkets.isEmpty)
        presenter.selectItem(at: 1)
        XCTAssertEqual(output.selectedMarkets, [.xyk])
        presenter.applyLocalization()
        controller.applyLocalization()
    }

    func testDisclaimerScreenReadsPersistsAndOpensLinks() throws {
        let settings = InMemorySettingsManager()
        let interactor = PolkaswapDisclaimerInteractor(userDefaultsStorage: settings)
        let router = CovDDisclaimerRouterSpy()
        let output = CovDSettingsOutputSpy()
        let presenter = PolkaswapDisclaimerPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: PolkaswapDisclaimerViewModelFactory(),
            moduleOutput: output,
            localizationManager: LocalizationManager.shared
        )
        let controller = PolkaswapDisclaimerViewController(output: presenter, localizationManager: LocalizationManager.shared)
        window = try CovDFixtures.host(controller)
        let layout = controller.rootView
        XCTAssertFalse(layout.confirmSwitch.isOn)
        XCTAssertTrue(layout.confirmSwitch.isUserInteractionEnabled)
        XCTAssertFalse(layout.continueButton.isEnabled)

        layout.confirmSwitch.isOn = true
        layout.confirmSwitch.sendActions(for: .allEvents)
        XCTAssertTrue(layout.continueButton.isEnabled)
        layout.continueButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.disclaimerReads, 1)
        XCTAssertEqual(router.dismissCount, 1)
        XCTAssertTrue(PolkaswapDisclaimerPolicy.isAccepted(in: settings))
        XCTAssertEqual(
            settings.integer(for: PolkaswapDisclaimerKeys.polkaswapDisclaimerAcceptedVersion.rawValue),
            PolkaswapDisclaimerPolicy.currentVersion
        )

        layout.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(router.dismissCount, 2)
        let link = try XCTUnwrap(URL(string: "https://polkaswap.io/#/terms"))
        presenter.didTappedOn(link: link)
        XCTAssertEqual(router.webURLs, [link])
        presenter.applyLocalization()
        controller.applyLocalization()

        presenter.didReceiveDisclaimer(isRead: true)
        XCTAssertTrue(layout.confirmSwitch.isOn)
        XCTAssertFalse(layout.confirmSwitch.isUserInteractionEnabled)

        let viewModel = PolkaswapDisclaimerViewModelFactory().buildViewModel(locale: Locale(identifier: "en_US"), delegate: presenter)
        XCTAssertFalse(viewModel.firstParagraph.string.isEmpty)
        XCTAssertFalse(viewModel.importantParagraph.string.isEmpty)
        XCTAssertFalse(viewModel.fourthParagraph.string.isEmpty)
        XCTAssertNotNil(PolkaswapDisclaimerAssembly.configureModule(moduleOutput: output))
    }

    func testDisclaimerPolicyMigratesTheReleasedFlagOnce() {
        let settings = InMemorySettingsManager()
        XCTAssertFalse(PolkaswapDisclaimerPolicy.isAccepted(in: settings))
        settings.set(value: true, for: PolkaswapDisclaimerKeys.polkaswapDisclaimerIsRead2.rawValue)
        XCTAssertTrue(PolkaswapDisclaimerPolicy.isAccepted(in: settings))
        XCTAssertEqual(settings.integer(for: PolkaswapDisclaimerKeys.polkaswapDisclaimerAcceptedVersion.rawValue), 2)
    }
}
