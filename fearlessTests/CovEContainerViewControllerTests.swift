@testable import fearless
import UIKit
import XCTest

/// `ContainerViewController`: content and draggable children, inset propagation, reload forwarding, programmatic and
/// pan-driven state transitions, and the adaptive two-column layout.
@MainActor
final class CovEContainerViewControllerTests: XCTestCase {
    func testEmbedsChildrenAndPropagatesInsetsAndReloads() throws {
        let content = CovEContainable()
        let draggable = CovEDraggable()
        let container = ContainerViewController()
        container.content = content
        container.draggable = draggable
        XCTAssertNil(container.presentationNavigationItem)
        XCTAssertFalse(container.supportsAdaptiveColumns)
        let window = CovEHost.window(for: container)
        defer { CovEHost.close(window) }
        container.view.layoutIfNeeded()

        XCTAssertTrue(container.children.contains(content))
        XCTAssertTrue(container.children.contains(draggable))
        XCTAssertTrue(content.view.superview === container.scrollView)
        XCTAssertTrue(draggable.view.superview === container.scrollView)
        XCTAssertTrue(draggable.delegate === container)
        XCTAssertTrue(content.reloadableDelegate === container)
        XCTAssertTrue(draggable.reloadableDelegate === container)
        XCTAssertGreaterThanOrEqual(content.contentInsets.bottom, 60, "The content keeps room for the compact panel")
        XCTAssertEqual(draggable.insets[.compact]?.top, UIConstants.defaultOffset)
        XCTAssertEqual(draggable.insets[.full]?.top, container.inheritedInsets.top)
        XCTAssertGreaterThan(draggable.view.frame.minY, 0, "The panel starts compact, below the content")
        XCTAssertEqual(container.draggableProgress, 0)
        XCTAssertFalse(container.scrollView.subviews.isEmpty)

        let pan = try XCTUnwrap(draggable.view.gestureRecognizers?.first as? UIPanGestureRecognizer)
        XCTAssertEqual(pan.maximumNumberOfTouches, 1)
        XCTAssertTrue(try container.gestureRecognizer(pan, shouldRecognizeSimultaneouslyWith: XCTUnwrap(draggable.scrollPanRecognizer)))
        XCTAssertFalse(container.gestureRecognizer(pan, shouldRecognizeSimultaneouslyWith: UIPanGestureRecognizer()))

        container.didInitiateReload(on: content)
        XCTAssertEqual(draggable.reloads, 1, "Reloading the content reloads the panel")
        container.didInitiateReload(on: draggable)
        XCTAssertEqual(content.reloads, 1, "Reloading the panel reloads the content")
        container.refreshControl.sendActions(for: .valueChanged)
        XCTAssertEqual(content.reloads, 2)

        let before = content.contentInsets
        container.willChangePreferredContentHeight()
        content.preferredContentHeight = 500
        container.didChangePreferredContentHeight(to: 500)
        XCTAssertLessThan(draggable.view.frame.height, CovEHost.phoneSize.height)
        XCTAssertNotEqual(content.contentInsets, before, "A taller content changes the bottom inset")

        container.view.frame.size.height -= 100
        container.view.setNeedsLayout()
        container.view.layoutIfNeeded()
        container.viewSafeAreaInsetsDidChange()
        XCTAssertNotNil(draggable.insets[.full])
    }

    func testProgrammaticTransitionsMoveThePanelAndShadow() {
        let content = CovEContainable()
        let draggable = CovEDraggable()
        let container = ContainerViewController()
        container.content = content
        container.draggable = draggable
        let window = CovEHost.window(for: container)
        defer { CovEHost.close(window) }
        let compactY = draggable.view.frame.minY
        let shadowCount = container.scrollView.subviews.count

        container.wantsTransit(to: .full, animating: false)
        XCTAssertEqual(draggable.view.frame.minY, 0)
        XCTAssertEqual(container.scrollView.subviews.count, shadowCount + 1, "The full panel dims the content with a shadow")
        container.wantsTransit(to: .full, animating: false)
        XCTAssertEqual(container.scrollView.subviews.count, shadowCount + 1)
        container.wantsTransit(to: .compact, animating: false)
        XCTAssertEqual(draggable.view.frame.minY, compactY)
        XCTAssertEqual(container.scrollView.subviews.count, shadowCount)

        container.wantsTransit(to: .full, animating: true)
        XCTAssertEqual(draggable.states.last?.0, .full)
        XCTAssertEqual(draggable.states.last?.1, true)
        CovEHost.spin(0.4)
        XCTAssertEqual(draggable.view.frame.minY, 0)
        container.wantsTransit(to: .compact, animating: true)
        CovEHost.spin(0.4)
        XCTAssertEqual(draggable.view.frame.minY, compactY)
        XCTAssertEqual(DraggableState.compact.other, .full)
        XCTAssertEqual(DraggableState.full.other, .compact)
    }

    func testPanGestureDragsToFullAndCancelsOppositeSwipes() {
        let content = CovEContainable()
        let draggable = CovEDraggable()
        let container = ContainerViewController()
        container.content = content
        container.draggable = draggable
        let window = CovEHost.window(for: container)
        defer { CovEHost.close(window) }
        let compactY = draggable.view.frame.minY
        let pan = CovEPan()

        drive(container, pan, .began, y: compactY)
        drive(container, pan, .changed, y: compactY - 300)
        XCTAssertEqual(draggable.view.frame.minY, max(0, compactY - 300), accuracy: 0.5, "The panel follows the finger")
        XCTAssertFalse(draggable.progresses.isEmpty, "The panel is told about the drag")
        pan.stubVelocity = CGPoint(x: 0, y: -400)
        drive(container, pan, .ended, y: compactY - 300)
        XCTAssertEqual(draggable.states.last?.0, .full, "A fast upward swipe opens the panel")
        CovEHost.spin(0.4)
        XCTAssertEqual(draggable.view.frame.minY, 0)

        pan.stubVelocity = CGPoint(x: 0, y: -50)
        drive(container, pan, .began, y: 10)
        drive(container, pan, .cancelled, y: 10)
        XCTAssertEqual(draggable.states.last?.0, .full, "Swiping up on a full panel keeps it full")

        draggable.canDragResult = false
        let count = draggable.progresses.count
        drive(container, pan, .began, y: 10)
        drive(container, pan, .changed, y: 200)
        XCTAssertEqual(draggable.progresses.count, count, "A panel that refuses dragging gets no progress")
        pan.stubVelocity = CGPoint(x: 0, y: 5)
        drive(container, pan, .ended, y: 200)
        XCTAssertEqual(draggable.states.last?.0, .full, "A slow drag with no progress settles back")
        drive(container, pan, .possible, y: 0)
        XCTAssertEqual(draggable.states.last?.0, .full)
    }

    func testAdaptiveContainerUsesColumnsOnRegularWidthPads() throws {
        guard #available(iOS 17.0, *) else {
            XCTFail("Trait overrides need iOS 17")
            return
        }
        let content = CovEContainable()
        let draggable = CovEDraggable()
        let container = CovEAdaptiveContainer()
        container.content = content
        container.draggable = draggable
        container.traitOverrides.userInterfaceIdiom = .pad
        container.traitOverrides.horizontalSizeClass = .regular
        let window = CovEHost.makeWindow(size: CGSize(width: 1180, height: 820))
        window.rootViewController = container
        window.isHidden = false
        defer { CovEHost.close(window) }
        container.view.layoutIfNeeded()
        XCTAssertEqual(container.inheritedInsets, .zero)
        XCTAssertTrue(container.usesAdaptiveColumns)
        XCTAssertEqual(container.scrollView.frame.width, 320)
        XCTAssertTrue(draggable.view.superview === container.view, "The list sits beside the summary")
        XCTAssertEqual(draggable.embedded.last, true)
        XCTAssertEqual(draggable.states.last?.0, .full)
        XCTAssertEqual(content.contentInsets, .zero)
        XCTAssertFalse(try XCTUnwrap(draggable.view.gestureRecognizers?.first).isEnabled)
        let transitions = draggable.states.count
        container.wantsTransit(to: .compact, animating: false)
        XCTAssertEqual(draggable.states.count, transitions, "Columns ignore panel transitions")
        container.didChangePreferredContentHeight(to: 10)

        container.traitOverrides.horizontalSizeClass = .compact
        container.view.setNeedsLayout()
        container.view.layoutIfNeeded()
        container.layoutAdaptivePanels()
        XCTAssertFalse(container.usesAdaptiveColumns)
        XCTAssertTrue(draggable.view.superview === container.scrollView)
        XCTAssertEqual(draggable.embedded.last, false)
        XCTAssertEqual(draggable.insets[.compact]?.top, 16)
        XCTAssertGreaterThan(container.draggableProgress, -1)
    }

    private func drive(_ container: ContainerViewController, _ pan: CovEPan, _ state: UIGestureRecognizer.State, y: CGFloat) {
        pan.stubState = state
        pan.stubLocation = CGPoint(x: 100, y: y)
        container.perform(NSSelectorFromString("handlePan:"), with: pan)
    }
}

final class CovEAdaptiveContainer: ContainerViewController {
    override var supportsAdaptiveColumns: Bool {
        true
    }
}

final class CovEContainable: UIViewController, Containable, Reloadable {
    var contentView: UIView {
        view
    }

    private(set) var contentInsets: UIEdgeInsets = .zero
    var preferredContentHeight: CGFloat = 240
    let observable = ViewModelObserverContainer<ContainableObserver>()
    weak var reloadableDelegate: ReloadableDelegate?
    private(set) var reloads = 0

    func setContentInsets(_ contentInsets: UIEdgeInsets, animated _: Bool) {
        self.contentInsets = contentInsets
    }

    func reload() {
        reloads += 1
    }
}

final class CovEDraggable: UIViewController, Draggable, Reloadable, AdaptiveSidePanel {
    var draggableView: UIView {
        view
    }

    weak var delegate: DraggableDelegate?
    let scrollPanRecognizer: UIPanGestureRecognizer? = UIPanGestureRecognizer()
    weak var reloadableDelegate: ReloadableDelegate?
    var canDragResult = true
    private(set) var states: [(DraggableState, Bool)] = []
    private(set) var insets: [DraggableState: UIEdgeInsets] = [:]
    private(set) var progresses: [Double] = []
    private(set) var embedded: [Bool] = []
    private(set) var reloads = 0

    func set(dragableState: DraggableState, animated: Bool) {
        states.append((dragableState, animated))
    }

    func set(contentInsets: UIEdgeInsets, for state: DraggableState) {
        insets[state] = contentInsets
    }

    func canDrag(from _: DraggableState) -> Bool {
        canDragResult
    }

    func animate(progress: Double, from _: DraggableState, to _: DraggableState, finalFrame: CGRect) {
        progresses.append(progress)
        view.frame = finalFrame
    }

    func reload() {
        reloads += 1
    }

    func setEmbeddedInColumns(_ embedded: Bool) {
        self.embedded.append(embedded)
    }
}

final class CovEPan: UIPanGestureRecognizer {
    var stubState: UIGestureRecognizer.State = .began
    var stubLocation: CGPoint = .zero
    var stubVelocity: CGPoint = .zero

    override var state: UIGestureRecognizer.State {
        get { stubState }
        set { stubState = newValue }
    }

    override func location(in _: UIView?) -> CGPoint {
        stubLocation
    }

    override func velocity(in _: UIView?) -> CGPoint {
        stubVelocity
    }
}
