import BigInt
import Foundation
import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class CovBAnEmbeddedModule: UIViewController, AnalyticsEmbeddedViewProtocol {
    let title1: String

    init(title: String) {
        title1 = title
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var localizedTitle: LocalizableResource<String> {
        let title = title1
        return LocalizableResource { _ in title }
    }
}

final class CovBAnRewardDetailsWireframeStub: AnalyticsRewardDetailsWireframeProtocol {
    private(set) var presented: [SheetAlertPresentableViewModel] = []
    private(set) var webURLs: [URL] = []

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        presented.append(viewModel)
    }

    func showWeb(url: URL, from _: ControllerBackedProtocol, style _: WebPresentableStyle) {
        webURLs.append(url)
    }
}

final class CovBAnRewardDetailsViewStub: UIViewController, AnalyticsRewardDetailsViewProtocol {
    private(set) var bound: [AnalyticsRewardDetailsViewModel] = []

    func bind(viewModel: LocalizableResource<AnalyticsRewardDetailsViewModel>) {
        bound.append(viewModel.value(for: Locale(identifier: "en_US")))
    }

    func applyLocalization() {}
}

final class CovBAnContainerTests: XCTestCase {
    private var locale: Locale { CovBAnFixtures.locale }

    func testContainerEmbedsModulesAndTitlesTheSegments() throws {
        let modules = [CovBAnEmbeddedModule(title: "One"), CovBAnEmbeddedModule(title: "Two")]
        let container = AnalyticsContainerViewController(embeddedModules: modules, localizationManager: LocalizationManager.shared)
        let window = CovBAnFixtures.host(container)
        container.view.layoutIfNeeded()

        XCTAssertEqual(container.children.count, 2)
        XCTAssertTrue(container.children.first === modules[0])
        XCTAssertTrue(container.children.last === modules[1])
        XCTAssertEqual(container.title, R.string.localizable.stakingAnalyticsTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(container.rootView.segmentedControl.titles, ["One", "Two"])
        XCTAssertTrue(modules.allSatisfy { $0.view.superview === container.rootView.horizontalScrollView })
        XCTAssertEqual(modules[0].view.frame.width, container.rootView.horizontalScrollView.frame.width, accuracy: 0.5)
        XCTAssertEqual(modules[1].view.frame.minX, modules[0].view.frame.maxX, accuracy: 0.5)
        XCTAssertTrue(container.rootView.horizontalScrollView.delegate === container)
        XCTAssertEqual(container.rootView.backgroundColor, R.color.colorBlack())
        XCTAssertEqual(container.rootView.segmentedControl.frame.height, 40)

        let scrollView = container.rootView.horizontalScrollView
        scrollView.contentOffset = CGPoint(x: scrollView.frame.width, y: 0)
        container.scrollViewDidEndDecelerating(scrollView)
        XCTAssertEqual(container.rootView.segmentedControl.selectedSegmentIndex, 1)

        container.rootView.segmentedControl.sendActions(for: .valueChanged)
        XCTAssertTrue(CovBAnFixtures.spin { scrollView.contentOffset.x == 0 })
        XCTAssertNotNil(window.rootViewController)
    }

    func testContainerWithoutModulesStillLocalizes() {
        let container = AnalyticsContainerViewController(embeddedModules: [])
        container.applyLocalization()
        XCTAssertNil(container.title, "Nothing is localized before the view loads")
        let window = CovBAnFixtures.host(container)
        XCTAssertTrue(container.children.isEmpty)
        XCTAssertEqual(container.rootView.segmentedControl.titles, [])
        XCTAssertTrue(window.rootViewController === container)
        XCTAssertEqual(container.title, R.string.localizable.stakingAnalyticsTitle(preferredLanguages: container.selectedLocale.rLanguages))
    }

    func testContainerFactoryBuildsRewardsAndStakeTabs() throws {
        let chainAsset = CovBAnFixtures.chainAsset()
        let wallet = CovBAnFixtures.wallet()

        let full = AnalyticsContainerViewFactory.createView(
            mode: [.includeValidatorsTab, .accountIsNominator],
            chainAsset: chainAsset,
            wallet: wallet,
            flow: .relaychain
        )
        XCTAssertEqual(full.embeddedModules.count, 2, "A chain without a connection has no validators tab")
        let rewards = try XCTUnwrap(full.embeddedModules.first as? AnalyticsRewardsViewController)
        XCTAssertTrue(rewards.presenter.accountIsNominator)
        XCTAssertTrue(full.embeddedModules.last is AnalyticsStakeViewController)

        let plain = AnalyticsContainerViewFactory.createView(mode: .none, chainAsset: chainAsset, wallet: wallet, flow: .relaychain)
        let plainRewards = try XCTUnwrap(plain.embeddedModules.first as? AnalyticsRewardsViewController)
        XCTAssertFalse(plainRewards.presenter.accountIsNominator)
        XCTAssertEqual(AnalyticsContainerViewMode(rawValue: 3), [.includeValidatorsTab, .accountIsNominator])
        XCTAssertNil(AnalyticsValidatorsViewFactory.createView(chain: chainAsset.chain, asset: chainAsset.asset, selectedAccount: wallet))
    }
}

final class CovBAnRewardDetailsTests: XCTestCase {
    private var locale: Locale { CovBAnFixtures.locale }

    func testDetailsScreenShowsTheRewardAndLocalizedTitles() throws {
        let chainAsset = CovBAnFixtures.chainAsset()
        let wallet = CovBAnFixtures.wallet()
        let reward = CovBAnFixtures.reward("123-4", daysAgo: 2, amount: 150)
        let view = try XCTUnwrap(AnalyticsRewardDetailsViewFactory.createView(rewardModel: reward, wallet: wallet, chainAsset: chainAsset))
        let controller = try XCTUnwrap(view.controller as? AnalyticsRewardDetailsViewController)
        let window = CovBAnFixtures.host(controller)

        let selected = controller.selectedLocale
        let layout = controller.rootView
        XCTAssertEqual(controller.title, R.string.localizable.commonDetails(preferredLanguages: selected.rLanguages))
        XCTAssertEqual(layout.eventIdView.subtitle, "123-4")
        XCTAssertEqual(layout.eventIdView.title, R.string.localizable.stakingCommonEventId(preferredLanguages: selected.rLanguages))
        XCTAssertEqual(layout.dateView.valueLabel.text, DateFormatter.txDetails.value(for: selected).string(from: reward.date))
        XCTAssertEqual(layout.typeView.valueLabel.text, R.string.localizable.stakingRewardDetailsReward(preferredLanguages: selected.rLanguages))
        let expectedAmount = BalanceViewModelFactory(targetAssetInfo: chainAsset.asset.displayInfo, selectedMetaAccount: wallet)
            .amountFromValue(1.5, usageCase: .detailsCrypto)
            .value(for: selected)
        XCTAssertEqual(layout.amountView.valueLabel.text, expectedAmount)
        XCTAssertEqual(layout.dateView.titleLabel.text, R.string.localizable.transactionDetailDate(preferredLanguages: selected.rLanguages))
        XCTAssertEqual(
            layout.typeView.titleLabel.text,
            R.string.localizable.stakingAnalyticsDetailsType(preferredLanguages: selected.rLanguages)
        )
        XCTAssertEqual(layout.amountView.titleLabel.text, R.string.localizable.walletSendAmountTitle(preferredLanguages: selected.rLanguages))
        XCTAssertEqual(layout.eventIdView.frame.height, 52)
        XCTAssertEqual(layout.dateView.frame.height, 48)

        layout.locale = Locale(identifier: "ja_JP")
        XCTAssertEqual(
            layout.dateView.titleLabel.text,
            R.string.localizable.transactionDetailDate(preferredLanguages: Locale(identifier: "ja_JP").rLanguages)
        )
        controller.applyLocalization()
        XCTAssertEqual(layout.locale, selected)
        XCTAssertTrue(window.rootViewController === controller)
    }

    func testEventIdActionOffersExplorersAndOpensThem() throws {
        let explorers = [
            ChainModel.ExternalApiExplorer(type: .polkascan, types: [.account], url: "https://polkascan.io/{type}/{value}"),
            ChainModel.ExternalApiExplorer(type: .subscan, types: [.account], url: "https://subscan.io/{type}/{value}")
        ]
        let chainAsset = CovBAnFixtures.chainAsset(explorers: explorers)
        let wireframe = CovBAnRewardDetailsWireframeStub()
        let view = CovBAnRewardDetailsViewStub()
        let presenter = AnalyticsRewardDetailsPresenter(
            rewardModel: CovBAnFixtures.reward("555-7", daysAgo: 1, amount: 150),
            interactor: AnalyticsRewardDetailsInteractor(),
            wireframe: wireframe,
            viewModelFactory: AnalyticsRewardDetailsViewModelFactory(
                chainAsset: chainAsset,
                balanceViewModelFactory: StubBalanceViewModelFactory()
            ),
            chainAsset: chainAsset
        )
        presenter.view = view

        presenter.setup()
        XCTAssertEqual(view.bound.map(\.eventId), ["555-7"])
        XCTAssertEqual(view.bound.map(\.amount), ["1.5"])

        presenter.handleEventIdAction()
        let sheet = try XCTUnwrap(wireframe.presented.first)
        let viewLocale = view.selectedLocale
        XCTAssertEqual(sheet.title, R.string.localizable.commonChooseAction(preferredLanguages: viewLocale.rLanguages))
        XCTAssertEqual(sheet.closeAction, R.string.localizable.commonCancel(preferredLanguages: viewLocale.rLanguages))
        XCTAssertEqual(sheet.actions.map(\.title), [
            R.string.localizable.commonCopyId(),
            R.string.localizable.transactionDetailsViewPolkascan(preferredLanguages: viewLocale.rLanguages),
            R.string.localizable.transactionDetailsViewSubscan(preferredLanguages: viewLocale.rLanguages)
        ])

        sheet.actions[1].handler?()
        sheet.actions[2].handler?()
        XCTAssertEqual(wireframe.webURLs.map(\.absoluteString), [
            "https://polkascan.io/account/555-7",
            "https://covbnet.subscan.io/account/555"
        ])
    }

    func testEventIdActionWithoutExplorersOffersOnlyCopy() throws {
        let chainAsset = CovBAnFixtures.chainAsset()
        let wireframe = CovBAnRewardDetailsWireframeStub()
        let presenter = AnalyticsRewardDetailsPresenter(
            rewardModel: CovBAnFixtures.reward("1-1", daysAgo: 1, amount: 1),
            interactor: AnalyticsRewardDetailsInteractor(),
            wireframe: wireframe,
            viewModelFactory: AnalyticsRewardDetailsViewModelFactory(
                chainAsset: chainAsset,
                balanceViewModelFactory: StubBalanceViewModelFactory()
            ),
            chainAsset: chainAsset
        )

        presenter.handleEventIdAction()

        XCTAssertEqual(wireframe.presented.first?.actions.map(\.title), [R.string.localizable.commonCopyId()])
        XCTAssertTrue(wireframe.webURLs.isEmpty)
    }
}
