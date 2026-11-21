@testable import fearless
import SoraUI
import UIKit
import XCTest

@MainActor
final class CovESheetAndSealTests: XCTestCase {
    func testScrollableSheetWrapsContentAndRunsHandlersAfterDismissal() throws {
        var events: [String] = []
        let action = SheetAlertPresentableAction(
            title: "Continue with this network and account",
            style: .warningStyle,
            handlerAfterDismissal: true,
            beforeDismissal: { events.append("before") },
            handler: { events.append("handler") }
        )
        let model = SheetAlertPresentableViewModel(
            title: "Review the details",
            message: String(repeating: "Long message. ", count: 80),
            actions: [action],
            closeAction: "Cancel",
            icon: nil,
            actionAxis: .horizontal,
            scrollableContent: true
        )
        let view = SheetAlertViewLayout(viewModel: model)
        let root = UIViewController()
        let child = UIViewController()
        let window = CovEHost.window(for: root)
        defer { CovEHost.close(window) }
        root.addChild(child)
        root.view.addSubview(child.view)
        child.view.frame = root.view.bounds
        child.didMove(toParent: root)
        child.view.addSubview(view)
        view.frame = CGRect(x: 16, y: 100, width: 358, height: 500)
        view.layoutIfNeeded()
        var complete: (() -> Void)?
        view.dismissAndHandle = { completion in events.append("dismiss"); complete = completion }
        XCTAssertNotNil(CovEFind.label("Review the details", in: view))
        XCTAssertNotNil(action.button.wrappingLabel)
        XCTAssertEqual(action.button.imageWithTitleView?.titleColor, R.color.colorPink())
        let actions = try XCTUnwrap(CovEFind.mirror(view, "actionsStackView", as: UIStackView.self))
        XCTAssertEqual(actions.axis, .vertical)
        XCTAssertEqual(actions.arrangedSubviews.count, 2)
        let scroll = try XCTUnwrap(CovEFind.mirror(view, "contentScrollView", as: UIScrollView.self))
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
        action.button.sendActions(for: .touchUpInside)
        XCTAssertEqual(events, ["before", "dismiss"])
        try XCTUnwrap(complete)()
        XCTAssertEqual(events, ["before", "dismiss", "handler"])
        CovESheetTraits.apply(to: child, in: root, view: view, contentSize: .accessibilityExtraExtraExtraLarge)
        XCTAssertEqual(view.traitCollection.preferredContentSizeCategory, .accessibilityExtraExtraExtraLarge)
        XCTAssertGreaterThan(try XCTUnwrap(CovEFind.label("Review the details", in: view)).font.pointSize, 18)
    }

    func testPlainAndInfoSheetsHonorCloseVisibilityAndImmediateActionOrder() throws {
        var events: [String] = []
        let action = SheetAlertPresentableAction(
            title: "Remove",
            handlerAfterDismissal: true,
            beforeDismissal: { events.append("before") },
            handler: { events.append("handler") }
        )
        let view = SheetAlertViewLayout(viewModel: .init(
            title: "Warning",
            message: nil,
            actions: [action],
            closeAction: nil,
            actionAxis: .horizontal,
            showsCloseButton: false
        ))
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 358, height: 360))
        defer { CovEHost.close(window) }
        view.closeButton.addAction(UIAction { _ in events.append("close") }, for: .touchUpInside)
        XCTAssertNil(view.closeButton.superview)
        let stack = try XCTUnwrap(CovEFind.mirror(view, "actionsStackView", as: UIStackView.self))
        XCTAssertEqual(stack.distribution, .fillEqually)
        action.button.sendActions(for: .touchUpInside)
        XCTAssertEqual(events, ["before", "close", "handler"])
        let info = SheetAlertViewLayout(viewModel: .init(
            title: "Information",
            message: "Details",
            actions: [],
            isInfo: true,
            closeAction: nil,
            icon: R.image.iconInfoGrayFill()
        ))
        let second = CovEHost.window(for: info, frame: CGRect(x: 16, y: 100, width: 358, height: 360))
        defer { CovEHost.close(second) }
        XCTAssertNil(info.closeButton.superview)
        XCTAssertNotNil(CovEFind.label("Details", in: info))
        let container = try XCTUnwrap(CovEFind.mirror(info, "imageViewContainer", as: UIView.self))
        let icon = try XCTUnwrap(container.subviews.compactMap { $0 as? UIImageView }.first)
        XCTAssertEqual(container.bounds.size, CGSize(width: 56, height: 56), "info sheets use the small icon disc")
        XCTAssertEqual(icon.bounds.size, CGSize(width: 32, height: 32))
        XCTAssertEqual(icon.image, R.image.iconInfoGrayFill())
    }

    func testAdaptiveSheetMovesLongMessageBetweenScrollAndInline() throws {
        let message = String(repeating: "A message that wraps on a narrow sheet. ", count: 12)
        let view = SheetAlertViewLayout(viewModel: .init(title: "Adaptive", message: message, actions: [], closeAction: nil, icon: nil))
        let root = UIViewController()
        let child = UIViewController()
        let window = CovEHost.window(for: root)
        defer { CovEHost.close(window) }
        root.addChild(child)
        root.view.addSubview(child.view)
        child.view.frame = CGRect(x: 0, y: 0, width: 390, height: 400)
        child.didMove(toParent: root)
        child.view.addSubview(view)
        view.frame = CGRect(x: 10, y: 10, width: 350, height: 400)
        CovESheetTraits.apply(to: child, in: root, view: view, idiom: .pad, horizontal: .regular)
        XCTAssertEqual(view.traitCollection.userInterfaceIdiom, .pad)
        view.layoutIfNeeded()
        let scroll = try XCTUnwrap(CovEFind.mirror(view, "scrollableView", as: ScrollableContainerView.self))
        let label = try XCTUnwrap(CovEFind.label(message, in: view))
        XCTAssertFalse(scroll.isHidden)
        XCTAssertTrue(label.superview === scroll.stackView)
        child.view.frame.size.height = 2400
        view.frame.size.height = 1000
        view.setNeedsLayout()
        view.layoutIfNeeded()
        XCTAssertTrue(scroll.isHidden)
        XCTAssertTrue(label.superview === CovEFind.mirror(view, "contentStackView", as: UIStackView.self))
    }

    func testTransferOverlayAdvancesAndRemovesOnEndOrBreak() throws {
        let container = UIView()
        let window = CovEHost.window(for: container, frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        defer { CovEHost.close(window); FWSealRecord.shared.reset() }
        FWTransferSeal.reach(.accepted, in: container, overlayWhenNoLoader: true)
        XCTAssertNil(FWTransferSeal.overlay(in: container))
        FWTransferSeal.reach(.ready, in: container)
        XCTAssertNil(FWTransferSeal.sealView(in: container))
        FWTransferSeal.reach(.ready, in: container, overlayWhenNoLoader: true)
        let overlay = try XCTUnwrap(FWTransferSeal.overlay(in: container))
        let seal = try XCTUnwrap(FWTransferSeal.sealView(in: container))
        XCTAssertFalse(overlay.isUserInteractionEnabled)
        XCTAssertTrue(overlay.accessibilityElementsHidden)
        XCTAssertEqual(overlay.frame, container.bounds)
        XCTAssertEqual(seal.bounds.width, FWTransferSeal.side)
        XCTAssertEqual(seal.center, CGPoint(x: 195, y: 422))
        FWTransferSeal.reach(.accepted, in: container)
        seal.stepSeal(byMs: 10000)
        XCTAssertEqual(seal.sealQ, FWSealStage.accepted.q)
        FWTransferSeal.end(in: container)
        XCTAssertTrue(CovEHost.spin(until: { FWTransferSeal.overlay(in: container) == nil }, timeout: 3))
        FWTransferSeal.reach(.ready, in: container, overlayWhenNoLoader: true)
        let broken = try XCTUnwrap(FWTransferSeal.overlay(in: container))
        FWTransferSeal.breakSeal(in: container)
        XCTAssertTrue(broken.isBreaking)
        XCTAssertTrue(FWTransferSeal.sealView(in: container)?.isSealBroken == true)
        FWTransferSeal.end(in: container)
        XCTAssertTrue(CovEHost.spin(until: { broken.superview == nil }, timeout: 4))
    }

    func testTransferSealReplacesLoaderAndFailureDetachesItForItsAnimation() throws {
        let container = UIView()
        let window = CovEHost.window(for: container, frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        defer { CovEHost.close(window); FWSealRecord.shared.reset() }
        let loader = FearlessLoadingViewFactory.createLoadingView()
        loader.frame = container.bounds
        loader.accessibilityIdentifier = LoadableViewProtocolConstants.activityIndicatorIdentifier
        container.addSubview(loader)
        let original = loader.subviews
        XCTAssertNotNil(CovEFind.first(FWMirrorLoaderView.self, in: loader))
        XCTAssertTrue(FWTransferSeal.loadingView(in: container) === loader)
        FWTransferSeal.reach(.ready, in: container)
        let seal = try XCTUnwrap(FWTransferSeal.sealView(in: container))
        XCTAssertTrue(seal.superview === loader)
        XCTAssertTrue(original.allSatisfy(\.isHidden))
        FWTransferSeal.breakSeal(in: container)
        XCTAssertTrue(seal.superview === container)
        XCTAssertTrue(seal.isSealBroken)
        XCTAssertFalse(seal.isUserInteractionEnabled)
        XCTAssertTrue(CovEHost.spin(until: { seal.superview == nil }, timeout: 4))
        FWTransferSeal.breakSeal(in: container)
        FWTransferSeal.end(in: container)
        XCTAssertNil(FWTransferSeal.sealView(in: container))
    }

    func testTransferEventsReportOnlyKnownStagesAndDefiniteFailure() {
        let recorder = CovESealRecorder()
        let failure = NSError(domain: "CovE-transfer", code: 1)
        XCTAssertEqual(FWTransferEvents.extrinsic(.success("hash")), .accepted)
        XCTAssertEqual(FWTransferEvents.extrinsic(.failure(failure)), .definiteFailure)
        XCTAssertEqual(FWTransferEvents.crossChain(.failure(failure)), .definiteFailure)
        XCTAssertEqual(FWTransferEvents.payouts([]), .outcomeUnknown)
        XCTAssertEqual(FWTransferEvents.payouts(["hash"]), .accepted)
        for event in [FWTransferEvent.authorised, .accepted, .definiteFailure, .outcomeUnknown] {
            FWTransferEvents.report(event, to: recorder)
        }
        XCTAssertEqual(recorder.stages, [.ready, .accepted])
        XCTAssertEqual(recorder.breaks, 1)
        FWTransferEvents.report(.accepted, to: NSObject())
        XCTAssertEqual(recorder.stages.count, 2)
    }
}

final class CovESealRecorder: FWTransferSealShowing {
    private(set) var stages: [FWSealStage] = []
    private(set) var breaks = 0
    func didReachTransferStage(_ stage: FWSealStage) {
        stages.append(stage)
    }

    func didBreakTransfer() {
        breaks += 1
    }
}

/// Applies trait overrides to a child controller and pushes them down to the sheet before it is laid out.
@MainActor
enum CovESheetTraits {
    static func apply(
        to child: UIViewController,
        in root: UIViewController,
        view: UIView,
        idiom: UIUserInterfaceIdiom? = nil,
        horizontal: UIUserInterfaceSizeClass? = nil,
        contentSize: UIContentSizeCategory? = nil
    ) {
        if #available(iOS 17.0, *) {
            if let idiom { child.traitOverrides.userInterfaceIdiom = idiom }
            if let horizontal { child.traitOverrides.horizontalSizeClass = horizontal }
            if let contentSize { child.traitOverrides.preferredContentSizeCategory = contentSize }
            child.view.updateTraitsIfNeeded()
            view.updateTraitsIfNeeded()
        } else {
            var traits: [UITraitCollection] = []
            if let idiom { traits.append(UITraitCollection(userInterfaceIdiom: idiom)) }
            if let horizontal { traits.append(UITraitCollection(horizontalSizeClass: horizontal)) }
            if let contentSize { traits.append(UITraitCollection(preferredContentSizeCategory: contentSize)) }
            root.setOverrideTraitCollection(UITraitCollection(traitsFrom: traits), forChild: child)
        }
        root.view.setNeedsLayout()
        root.view.layoutIfNeeded()
        view.layoutIfNeeded()
    }
}
