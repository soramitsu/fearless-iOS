import Foundation
import UIKit
import SwiftUI

protocol SwipeButtonProtocol: UIButton {
    var type: SwipableCellButtonType { get }
}

enum SwipableCellButtonType: Int, CaseIterable {
    case send
    case receive
    case teleport
    case hide
    case show
}

protocol SwipableTableViewCellDelegate: AnyObject {
    func swipeCellDidTap(on actionType: SwipableCellButtonType, with indexPath: IndexPath?)
}

// swiftlint:disable type_body_length file_length
class SwipableTableViewCell: UITableViewCell {
    // MARK: - Public properties

    weak var delegate: SwipableTableViewCellDelegate?

    /// The content view of a SwipableTableViewCell object is the default superview for content that the cell displays.
    /// If you want to customize cells by simply adding additional views, you should add them to the content view so
    /// they position appropriately as the cell transitions in to and out of editing mode.
    let cloudView = UIView()
    /// Backgrount view for action swipe menu from left side
    var leftMenuBackgroundView: TriangularedView = {
        let containerView = TriangularedView()
        containerView.fillColor = R.color.colorWhite8()!
        containerView.highlightedFillColor = R.color.colorWhite8()!
        containerView.shadowOpacity = 0
        return containerView
    }()

    /// Backgrount view for action swipe menu from right side
    var rightMenuBackgroundView: TriangularedView = {
        let containerView = TriangularedView()
        containerView.fillColor = R.color.colorWhite8()!
        containerView.highlightedFillColor = R.color.colorWhite8()!
        containerView.shadowOpacity = 0
        return containerView
    }()

    var cloudViewEdgeInsets: UIEdgeInsets {
        UIEdgeInsets(
            top: UIConstants.defaultOffset,
            left: UIConstants.bigOffset,
            bottom: 0,
            right: UIConstants.bigOffset
        )
    }

    var actionButtonWidht: CGFloat {
        UIConstants.swipeTableActionButtonWidth
    }

    var openMenuTrigger: CGFloat {
        actionButtonWidht * 0.7
    }

    var rightMenuButtons: [SwipeButtonProtocol] = []
    var leftMenuButtons: [SwipeButtonProtocol] = []

    var closeSwipeAnimationDuration: TimeInterval {
        0.3
    }

    // MARK: - Private properties

    private let leftMenuMenuWrapper: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        return view
    }()

    private let rightMenuMenuWrapper: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        return view
    }()

    // MARK: - Private swipe state

    private var startPosition: CGPoint = .zero
    private var leadingOffset: CGFloat = 0
    private var isSwiping = false
    private var swipeDirectional: SwipeState = .ended
    private var isSwipeOpen: Bool {
        isLeftMenuOpen || isRightMenuOpen
    }

    private var isLeftMenuOpen: Bool {
        cloudView.frame.minX > cloudViewEdgeInsets.left
    }

    private var leftMenuWidth: CGFloat {
        CGFloat(leftMenuButtons.count) * actionButtonWidht
    }

    private var isRightMenuOpen: Bool {
        cloudView.frame.minX < 0
    }

    private var rightMenuWidth: CGFloat {
        CGFloat(rightMenuButtons.count) * actionButtonWidht
    }

    // MARK: - Constructors

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        createBaseUI()
        panGestureConfigure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cloudView.snp.updateConstraints { make in
            make.leading.equalToSuperview().offset(cloudViewEdgeInsets.left)
        }
        cloudView.gestureRecognizers?.forEach { gesture in
            gesture.reset()
        }

        rightMenuBackgroundView.subviews.forEach { $0.removeFromSuperview() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateActionMenu(
            with: leftMenuButtons,
            container: leftMenuMenuWrapper,
            isLeftMenu: true
        )
        updateActionMenu(
            with: rightMenuButtons,
            container: rightMenuMenuWrapper,
            isLeftMenu: false
        )
    }

    // MARK: - UIPanGestureRecognizer

    @objc private func panGesture(gesture: UIPanGestureRecognizer) {
        guard
            !leftMenuButtons.isEmpty || !rightMenuButtons.isEmpty,
            usedTableView?.isDecelerating == false,
            usedTableView?.isDragging == false
        else {
            if gesture.state == .ended {
                isSwiping = false
                closeSwipe()
            }
            return
        }

        switch gesture.state {
        case .began:
            handleBeganGestureState(with: gesture)

        case .changed:
            handleChangedGestureState(with: gesture)

        default:
            handleDefauleGestureState(with: gesture)
        }
    }

    private func handleBeganGestureState(with gesture: UIPanGestureRecognizer) {
        isSwiping = true
        startPosition = gesture.location(in: self)
        leadingOffset = cloudView.frame.origin.x
        swipeDirectional = SwipeState(velocity: gesture.velocity(in: self).x)

        if let swipableVisibleCells = usedTableView?.visibleCells as? [SwipableTableViewCell] {
            swipableVisibleCells.forEach { $0.closeSwipe() }
        }
    }

    // MARK: - handle default gesture state

    private func handleDefauleGestureState(with gesture: UIPanGestureRecognizer) {
        isSwiping = false
        let nowPosition = gesture.location(in: self)
        let diff = startPosition.x - nowPosition.x

        switch swipeDirectional {
        case .ended:
            break
        case .rightToLeft:
            guard rightMenuButtons.isNotEmpty else {
                return
            }
            isLeftMenuOpen
                ? tryOpenLeftMenu(with: -diff)
                : tryOpenRightMenu(with: diff)
        case .leftToRight:
            guard leftMenuButtons.isNotEmpty else {
                return
            }
            isRightMenuOpen
                ? tryOpenRightMenu(with: diff)
                : tryOpenLeftMenu(with: -diff)
        }
        swipeDirectional = .ended
    }

    private func tryOpenLeftMenu(with diff: CGFloat) {
        var leading: CGFloat = cloudViewEdgeInsets.left

        var alpha: CGFloat
        if diff >= openMenuTrigger {
            leading = leftMenuWidth + cloudViewEdgeInsets.left + cloudViewEdgeInsets.right
            alpha = 1
        } else {
            alpha = 0
        }

        cloudView.snp.updateConstraints { make in
            make.leading.equalToSuperview().offset(leading)
        }

        UIView.animate(withDuration: closeSwipeAnimationDuration) {
            self.layoutIfNeeded()
            self.leftMenuMenuWrapper.alpha = alpha
        }
    }

    private func tryOpenRightMenu(with diff: CGFloat) {
        var leading: CGFloat = cloudViewEdgeInsets.left

        var alpha: CGFloat
        if diff >= openMenuTrigger {
            leading = -rightMenuWidth
            alpha = 1
        } else {
            alpha = 0
        }

        cloudView.snp.updateConstraints { make in
            make.leading.equalToSuperview().offset(leading)
        }

        UIView.animate(withDuration: closeSwipeAnimationDuration) {
            self.rightMenuMenuWrapper.alpha = alpha
            self.layoutIfNeeded()
        }
    }

    // MARK: - handle changed state gesture

    private func handleChangedGestureState(with gesture: UIPanGestureRecognizer) {
        let nowPosition = gesture.location(in: self)
        let diff = nowPosition.x - startPosition.x + leadingOffset

        switch swipeDirectional {
        case .ended:
            break
        case .rightToLeft:
            guard rightMenuButtons.isNotEmpty else {
                return
            }
            if isLeftMenuOpen {
                handleLeftToRight(with: -diff)
            } else {
                handleRightToLeft(with: diff)
            }
        case .leftToRight:
            guard leftMenuButtons.isNotEmpty else {
                return
            }
            if isRightMenuOpen {
                handleRightToLeft(with: diff)
            } else {
                handleLeftToRight(with: -diff)
            }
        }

        layoutIfNeeded()
    }

    private func handleLeftToRight(with diff: CGFloat) {
        let maxLeading = -leftMenuWidth - cloudViewEdgeInsets.left + cloudViewEdgeInsets.right
        let max = max(maxLeading, diff)
        let leading = min(cloudViewEdgeInsets.left, max)
        let alpha = abs(max / maxLeading)

        leftMenuMenuWrapper.alpha = alpha

        cloudView.snp.updateConstraints { make in
            make.leading.equalToSuperview().offset(abs(leading))
        }
    }

    private func handleRightToLeft(with diff: CGFloat) {
        let maxLeading = -rightMenuWidth - cloudViewEdgeInsets.left + cloudViewEdgeInsets.right
        let max = max(maxLeading, diff)
        let leading = min(cloudViewEdgeInsets.left, max)
        let alpha = abs(max / maxLeading)

        rightMenuMenuWrapper.alpha = alpha

        cloudView.snp.updateConstraints { make in
            make.leading.equalToSuperview().offset(leading)
        }
    }

    private func closeSwipe() {
        guard isSwiping == false, isSwipeOpen else {
            return
        }

        cloudView.snp.updateConstraints { make in
            make.leading.equalToSuperview().offset(cloudViewEdgeInsets.left)
        }

        UIView.animate(withDuration: closeSwipeAnimationDuration) {
            self.layoutIfNeeded()
            self.leftMenuMenuWrapper.alpha = 0
            self.rightMenuMenuWrapper.alpha = 0
        }
    }

    // MARK: - Private methods

    private func updateActionMenu(
        with buttons: [SwipeButtonProtocol],
        container: UIView,
        isLeftMenu: Bool
    ) {
        guard container.frame != .zero else {
            return
        }
        container.subviews.forEach { view in
            view.removeFromSuperview()
        }

        let buttonContainer = isLeftMenu ? leftMenuBackgroundView : rightMenuBackgroundView
        buttonContainer.frame.size = CGSize(
            width: isLeftMenu ? leftMenuWidth : rightMenuWidth,
            height: container.frame.size.height
        )
        buttonContainer.frame.origin = CGPoint(
            x: container.bounds.origin.x,
            y: 0
        )

        container.addSubview(buttonContainer)

        func calculateSeparatorFrame(for button: UIButton) -> CGRect {
            CGRect(
                x: button.bounds.maxX,
                y: button.bounds.minY + UIConstants.defaultOffset,
                width: UIConstants.separatorHeight,
                height: button.frame.size.height - UIConstants.defaultOffset * 2
            )
        }

        func calculateButtonFrame(for index: Int) -> CGRect {
            CGRect(
                x: actionButtonWidht * CGFloat(index),
                y: 0,
                width: actionButtonWidht,
                height: container.frame.size.height
            )
        }

        for (index, button) in buttons.enumerated() {
            button.addTarget(self, action: #selector(handleAction), for: .touchUpInside)

            buttonContainer.addSubview(button)
            button.frame = calculateButtonFrame(for: index)
            if index != buttons.count - 1 {
                let separator = UIFactory.default.createSeparatorView()
                button.addSubview(separator)
                separator.frame = calculateSeparatorFrame(for: button)
            }
        }
    }

    @objc private func handleAction(_ sender: UIButton) {
        guard let buttonType = SwipableCellButtonType(rawValue: sender.tag) else {
            return
        }
        delegate?.swipeCellDidTap(on: buttonType, with: indexPath)
        closeSwipe()
    }

    private func createBaseUI() {
        contentView.addSubview(cloudView)
        cloudView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(cloudViewEdgeInsets.left)
            make.trailing.equalToSuperview().inset(cloudViewEdgeInsets.right).priority(.low)
            make.top.equalToSuperview().offset(cloudViewEdgeInsets.top)
            make.bottom.equalToSuperview().inset(cloudViewEdgeInsets.bottom)
            make.width.equalToSuperview().offset(-(cloudViewEdgeInsets.left + cloudViewEdgeInsets.right))
        }

        contentView.insertSubview(rightMenuMenuWrapper, belowSubview: cloudView)
        rightMenuMenuWrapper.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.equalTo(cloudView.snp.trailing).inset(-cloudViewEdgeInsets.left).priority(.low)
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview()
        }

        contentView.insertSubview(leftMenuMenuWrapper, belowSubview: cloudView)
        leftMenuMenuWrapper.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.bigOffset)
            make.trailing.equalTo(cloudView.snp.leading).inset(-cloudViewEdgeInsets.right).priority(.low)
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview()
        }
    }

    private func panGestureConfigure() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGesture))
        panGesture.delegate = self
        cloudView.isUserInteractionEnabled = true
        cloudView.addGestureRecognizer(panGesture)
    }
}

// MARK: - gesture recognizer

extension SwipableTableViewCell {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer is UIPanGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }

        if leftMenuButtons.isEmpty, rightMenuButtons.isEmpty {
            return false
        }

        if usedTableView?.isDecelerating == true {
            return false
        }

        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    override func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard
            let gesture = gestureRecognizer as? UIPanGestureRecognizer,
            let scrollView = otherGestureRecognizer.view as? UIScrollView
        else {
            return true
        }

        if isSwiping {
            return false
        }

        let velocityX = gesture.velocity(in: gesture.view).x
        if abs(velocityX) > abs(scrollView.contentOffset.y) {
            return true
        }

        if velocityX < 0 || isSwipeOpen {
            return true
        }

        if
            scrollView.isTracking,
            let swipableVisibleCells = usedTableView?.visibleCells as? [SwipableTableViewCell] {
            swipableVisibleCells.forEach { $0.closeSwipe() }
            return true
        }

        return false
    }
}

private enum SwipeState {
    case ended
    case rightToLeft
    case leftToRight

    init(velocity: CGFloat) {
        if velocity > 0 {
            self = .leftToRight
        } else {
            self = .rightToLeft
        }
    }
}
