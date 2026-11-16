import XCTest
import UIKit
import SSFModels
import SoraFoundation
@testable import fearless

final class CovJAcctAllDoneViewStub: UIViewController, AllDoneViewInput {
    var viewModels: [AllDoneViewModel] = []
    var explorers: [ChainModel.ExternalApiExplorer?] = []

    func didReceive(viewModel: AllDoneViewModel) { viewModels.append(viewModel) }
    func didReceive(explorer: ChainModel.ExternalApiExplorer?) { explorers.append(explorer) }
}

final class CovJAcctAllDoneInteractorStub: AllDoneInteractorInput {
    weak var output: AllDoneInteractorOutput?
    func setup(with output: AllDoneInteractorOutput) { self.output = output }
}

final class CovJAcctAllDoneRouterStub: AllDoneRouterInput {
    var subscans: [URL] = []
    var shared: [[Any]] = []
    var dismissals = 0
    var statuses: [ApplicationStatusAlertEvent] = []

    func presentSubscan(from _: ControllerBackedProtocol?, url: URL) { subscans.append(url) }
    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
    func presentStatus(with viewModel: ApplicationStatusAlertEvent, animated _: Bool) { statuses.append(viewModel) }
    func dismissStatus(with _: ApplicationStatusAlertEvent?, animated _: Bool) {}
    func share(source _: UIActivityItemSource, from _: ControllerBackedProtocol?, with _: SharingCompletionHandler?) {}
    func share(sources: [Any], from _: ControllerBackedProtocol?, with _: SharingCompletionHandler?) { shared.append(sources) }
}

final class CovJAcctAllDoneOutputSpy: AllDoneViewOutput {
    var loads = 0
    var dismissals = 0
    var copies = 0
    var willDismiss = 0
    var explorerTaps = 0
    var shareTaps = 0

    func didLoad(view _: AllDoneViewInput) { loads += 1 }
    func dismiss() { dismissals += 1 }
    func didCopyTapped() { copies += 1 }
    func presentationControllerWillDismiss() { willDismiss += 1 }
    func explorerButtonDidTapped() { explorerTaps += 1 }
    func shareButtonDidTapped() { shareTaps += 1 }
}

final class CovJAcctFeedbackSpy: FWFeedbackPlaying {
    var patterns: [FWFeedbackPattern] = []
    func play(_ pattern: FWFeedbackPattern) -> FWFeedbackOutcome {
        patterns.append(pattern)
        return FWFeedbackOutcome()
    }
}

enum CovJAcctAllDoneFixture {
    static let explorer = ChainModel.ExternalApiExplorer(
        type: .subscan, types: [.extrinsic], url: "https://scan.invalid/{type}/{value}"
    )

    static func chainAsset(explorers: [ChainModel.ExternalApiExplorer]?) -> ChainAsset {
        let asset = CovJFixture.asset(id: "dot", symbol: "DOT")
        let chain = ChainModel(
            rank: nil, disabled: false, chainId: UUID().uuidString, parentId: nil, paraId: nil, name: "Polkadot", xcm: nil,
            nodes: [CovJFixture.node("polkadot")], addressPrefix: 0, types: nil, icon: nil, options: nil,
            externalApi: ChainModel.ExternalApiSet(explorers: explorers), selectedNode: nil, customNodes: nil,
            iosMinAppVersion: nil, identityChain: nil
        )
        chain.assets = [asset]
        return ChainAsset(chain: chain, asset: asset)
    }
}

final class CovJAcctAllDonePresenterTests: XCTestCase {
    private var languages: [String]? { LocalizationManager.shared.selectedLocale.rLanguages }

    private func make(
        hash: String? = "0xabc", explorers: [ChainModel.ExternalApiExplorer]? = [CovJAcctAllDoneFixture.explorer],
        title: String? = nil, closure: (() -> Void)? = nil, walletConnect: Bool = false
    ) -> (AllDonePresenter, CovJAcctAllDoneViewStub, CovJAcctAllDoneInteractorStub, CovJAcctAllDoneRouterStub) {
        let interactor = CovJAcctAllDoneInteractorStub()
        let router = CovJAcctAllDoneRouterStub()
        let presenter = AllDonePresenter(
            chainAsset: CovJAcctAllDoneFixture.chainAsset(explorers: explorers), hashString: hash, interactor: interactor,
            router: router, viewModelFactory: AllDoneViewModelFactory(), closure: closure, title: title, description: nil,
            isWalletConnectResult: walletConnect, localizationManager: LocalizationManager.shared
        )
        let view = CovJAcctAllDoneViewStub()
        presenter.didLoad(view: view)
        return (presenter, view, interactor, router)
    }

    func testLoadBindsDefaultTextsAndExplorer() {
        let (presenter, view, interactor, _) = make()

        XCTAssertTrue(interactor.output === presenter)
        let viewModel = view.viewModels.first
        XCTAssertEqual(viewModel?.title, R.string.localizable.allDoneAlertAllDoneStub(preferredLanguages: languages))
        XCTAssertEqual(viewModel?.description, R.string.localizable.allDoneAlertDescriptionStub(preferredLanguages: languages))
        XCTAssertEqual(viewModel?.extrinsicHash, "0xabc")
        XCTAssertEqual(viewModel?.isWalletConnectResult, false)
        XCTAssertEqual(view.explorers.count, 1)
        XCTAssertEqual(view.explorers.first??.url, CovJAcctAllDoneFixture.explorer.url)

        presenter.applyLocalization()
        XCTAssertEqual(view.viewModels.count, 2)
    }

    func testExplorerShareDismissCopyAndClosure() throws {
        var closed = 0
        let (presenter, _, _, router) = make(title: "Sent", closure: { closed += 1 })

        presenter.explorerButtonDidTapped()
        presenter.shareButtonDidTapped()
        presenter.dismiss()
        presenter.didCopyTapped()
        presenter.presentationControllerWillDismiss()

        XCTAssertEqual(router.subscans.map(\.absoluteString), ["https://scan.invalid/extrinsic/0xabc"])
        XCTAssertEqual((router.shared.first?.first as? URL)?.absoluteString, "https://scan.invalid/extrinsic/0xabc")
        XCTAssertEqual(router.dismissals, 1)
        XCTAssertEqual(router.statuses.count, 1)
        XCTAssertTrue(router.statuses.first is HashCopiedEvent)
        XCTAssertEqual(closed, 1)
    }

    func testWithoutHashOrExplorerNothingIsOpened() {
        let (noHash, noHashView, _, noHashRouter) = make(hash: nil, walletConnect: true)
        XCTAssertEqual(noHashView.explorers.count, 1)
        XCTAssertNil(noHashView.explorers.first ?? nil)
        XCTAssertEqual(noHashView.viewModels.first?.isWalletConnectResult, true)
        noHash.explorerButtonDidTapped()
        noHash.shareButtonDidTapped()
        XCTAssertTrue(noHashRouter.subscans.isEmpty)
        XCTAssertTrue(noHashRouter.shared.isEmpty)

        let (noExplorer, view, _, router) = make(explorers: nil)
        XCTAssertNil(view.explorers.first ?? nil)
        noExplorer.explorerButtonDidTapped()
        noExplorer.shareButtonDidTapped()
        noExplorer.presentationControllerWillDismiss()
        XCTAssertTrue(router.subscans.isEmpty)
        XCTAssertTrue(router.shared.isEmpty)
    }

    func testViewModelFactoryKeepsProvidedTexts() {
        let viewModel = AllDoneViewModelFactory().buildViewModel(
            title: "Title", description: "Body", extrinsicHash: nil, locale: CovJFixture.locale, isWalletConnectResult: true
        )
        XCTAssertEqual(viewModel.title, "Title")
        XCTAssertEqual(viewModel.description, "Body")
        XCTAssertNil(viewModel.extrinsicHash)
        XCTAssertTrue(viewModel.isWalletConnectResult)
    }
}

final class CovJAcctAllDoneViewTests: XCTestCase {
    func testControllerForwardsButtonsAndBindsViewModels() throws {
        let output = CovJAcctAllDoneOutputSpy()
        let feedback = CovJAcctFeedbackSpy()
        let controller = AllDoneViewController(
            output: output, localizationManager: LocalizationManager.shared, celebration: .send, feedback: feedback
        )
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = controller.rootView
        XCTAssertEqual(output.loads, 1)

        controller.viewDidAppear(false)
        controller.viewDidAppear(false)
        XCTAssertEqual(feedback.patterns.filter { $0 == .send }.count, 1)
        XCTAssertFalse(root.solarGeometryView.isHidden)

        root.closeButton.sendActions(for: .touchUpInside)
        root.mainCloseButton.sendActions(for: .touchUpInside)
        root.subscanButton.sendActions(for: .touchUpInside)
        root.shareButton.sendActions(for: .touchUpInside)
        root.copyOnTap?()
        XCTAssertEqual(output.dismissals, 2)
        XCTAssertEqual(output.explorerTaps, 1)
        XCTAssertEqual(output.shareTaps, 1)
        XCTAssertEqual(output.copies, 1)

        controller.didReceive(viewModel: AllDoneViewModel(title: "Done", description: "Sent", extrinsicHash: "0x01", isWalletConnectResult: false))
        XCTAssertEqual(root.titleLabel.text, "Done")
        XCTAssertTrue(root.mainCloseButton.isHidden)

        controller.didReceive(explorer: CovJAcctAllDoneFixture.explorer)
        XCTAssertFalse(root.subscanButton.isHidden)
        XCTAssertFalse(root.shareButton.isHidden)
        XCTAssertEqual(root.subscanButton.imageWithTitleView?.title, "Subscan")
        controller.didReceive(explorer: nil)
        XCTAssertTrue(root.subscanButton.isHidden)
        XCTAssertTrue(root.shareButton.isHidden)

        controller.didReceive(viewModel: AllDoneViewModel(title: "Linked", description: "", extrinsicHash: nil, isWalletConnectResult: true))
        XCTAssertFalse(root.mainCloseButton.isHidden)

        controller.applyLocalization()
        XCTAssertEqual(root.locale, LocalizationManager.shared.selectedLocale)
        controller.viewDidDisappear(false)
        XCTAssertEqual(output.willDismiss, 1)
    }

    func testSolarGeometryContinuesARecentSeal() throws {
        let layout = AllDoneViewLayout()
        let record = FWSealRecord()
        record.note(.sent)
        XCTAssertEqual(record.recent(), .sent)

        layout.igniteSolarGeometry(sealRecord: record)

        XCTAssertFalse(layout.solarGeometryView.isHidden)
        XCTAssertNil(record.recent(), "The record is consumed by the success screen")
        layout.igniteSolarGeometry(sealRecord: record)
        XCTAssertFalse(layout.solarGeometryView.isHidden)
    }

    func testAssemblyAndRouterBuildControllers() throws {
        let module = try XCTUnwrap(AllDoneAssembly.configureModule(
            chainAsset: CovJAcctAllDoneFixture.chainAsset(explorers: nil), hashString: "0x02", title: "T", description: "D",
            closure: nil, isWalletConnectResult: false, celebration: nil
        ))
        XCTAssertTrue(module.view.controller is AllDoneViewController)
        XCTAssertTrue(module.input is AllDonePresenter)

        let host = try CovJHostedView()
        defer { host.close() }
        AllDoneRouter().presentSubscan(from: nil, url: try XCTUnwrap(URL(string: "https://scan.invalid/extrinsic/0x02")))
        XCTAssertNil(host.presented, "Without a view there is nothing to present from")
    }
}
