import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

@IBDesignable
open class PlainSegmentedControl: UIControl {
    private struct Constants {
        static let selectionAnimationKey = "selectionAnimationKey"
    }

    open var titles: [String] = ["Segment1", "Segment2"] {
        didSet {
            if oldValue.count != titles.count {
                _selectedSegmentIndex = titles.count > 0 ? 0 : -1
            }

            clearSegments()
            buildSegments()

            setNeedsLayout()
        }
    }

    open var selectedSegmentIndex: Int {
        set {
            _selectedSegmentIndex = newValue
            updateSelectionLayerFrame()
            updateSegmentsSelection()
        }

        get {
            return _selectedSegmentIndex
        }
    }

    open var numberOfSegments: Int {
        return titles.count
    }

    open var titleColor: UIColor = .black {
        didSet {
            updateSegmentsSelection()
        }
    }

    open var selectedTitleColor: UIColor = .white {
        didSet {
            if _selectedSegmentIndex >= 0 {
                segments[_selectedSegmentIndex].textColor = selectedTitleColor
            }
        }
    }

    open var titleFont: UIFont? {
        didSet {
            segments.forEach { $0.font = titleFont }
        }
    }

    open var selectionColor: UIColor = .white {
        didSet {
            applySelectionColor()
        }
    }

    open var selectionWidth: CGFloat = 2.0 {
        didSet {
            applySelectionPath()
            updateSelectionLayerFrame()
        }
    }

    open var layoutStrategy: ListViewLayoutStrategyProtocol = HorizontalEqualWidthLayoutStrategy() {
        didSet {
            setNeedsLayout()
        }
    }

    open var selectionAnimationDuration: TimeInterval = 0.2

    open var selectionTimingOption: CAMediaTimingFunctionName = .linear

    private var _selectedSegmentIndex: Int = 0
    private var segments: [UILabel] = []
    private var selectionLayer: CAShapeLayer = CAShapeLayer()

    private var selectedTitleLabel: UILabel? {
        return selectedSegmentIndex >= 0 ? segments[selectedSegmentIndex] : nil
    }

    // MARK: Overriden initializers

    override open var frame: CGRect {
        didSet {
            setNeedsLayout()
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    open override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        if titles.count != segments.count {
            configure()
        }
    }

    open func configure() {
        self.backgroundColor = UIColor.clear

        buildSegments()
        configureSelectionLayer()
    }

    private func configureSelectionLayer() {
        layer.addSublayer(selectionLayer)

        applySelectionColor()
        applySelectionPath()
        updateSelectionLayerFrame()
    }

    // MARK: Layout

    open override func layoutSubviews() {
        super.layoutSubviews()


        layoutStrategy.layout(views: segments, in: bounds)

        applySelectionPath()
        updateSelectionLayerFrame()
    }

    // MARK: Segments Management

    private func buildSegments() {
        guard titles.count > 0 else {
            return
        }

        for (index, title) in titles.enumerated() {
            let segmentLabel = UILabel()
            segmentLabel.backgroundColor = .clear
            segmentLabel.textAlignment = .center
            segmentLabel.text = title
            segmentLabel.isUserInteractionEnabled = true
            addSubview(segmentLabel)

            applyStyle(for: segmentLabel, at: index)

            segments.append(segmentLabel)

            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapSegment(_:)))
            segmentLabel.addGestureRecognizer(tapRecognizer)
        }
    }

    private func clearSegments() {
        segments.forEach { $0.removeFromSuperview() }
        segments.removeAll()
    }

    private func applyStyle(for segmentLabel: UILabel, at index: Int) {
        segmentLabel.textColor = index == _selectedSegmentIndex ? selectedTitleColor : titleColor
        segmentLabel.font = titleFont
    }

    // MARK: Selection Management

    private func applySelectionColor() {
        selectionLayer.strokeColor = selectionColor.cgColor
    }

    private func applySelectionPath() {
        guard let width = selectedTitleLabel?.frame.size.width else {
            return
        }

        let selectionPath = UIBezierPath()
        selectionPath.move(to: CGPoint(x: 0.0, y: selectionWidth / 2.0))
        selectionPath.addLine(to: CGPoint(x: width, y: selectionWidth / 2.0))

        selectionLayer.path = selectionPath.cgPath
        selectionLayer.lineWidth = selectionWidth
    }

    private func updateSelectionLayerFrame() {
        guard let titleLabel = selectedTitleLabel else {
            return
        }

        selectionLayer.frame = CGRect(x: titleLabel.frame.origin.x,
                                      y: bounds.maxY - selectionWidth,
                                      width: titleLabel.frame.size.width,
                                      height: selectionWidth)
    }

    private func updateSegmentsSelection() {
        for (index, label) in segments.enumerated() {
            label.textColor = index == _selectedSegmentIndex ? selectedTitleColor : titleColor
        }
    }

    private func animateSelectionIndexChange(_ fromIndex: Int) {
        selectionLayer.removeAnimation(forKey: Constants.selectionAnimationKey)

        let previousLabel = segments[fromIndex]

        guard let titleLabel = selectedTitleLabel else {
            return
        }

        let oldFrame = CGRect(x: previousLabel.frame.origin.x,
                              y: bounds.maxY - selectionWidth,
                              width: previousLabel.frame.size.width,
                              height: selectionWidth)

        let newFrame = CGRect(x: titleLabel.frame.origin.x,
                              y: bounds.maxY - selectionWidth,
                              width: titleLabel.frame.size.width,
                              height: selectionWidth)

        let animation = CABasicAnimation(keyPath: "frame")
        animation.fromValue = oldFrame
        animation.toValue = newFrame
        animation.duration = selectionAnimationDuration
        animation.timingFunction = CAMediaTimingFunction(name: selectionTimingOption)

        selectionLayer.frame = newFrame

        selectionLayer.add(animation, forKey: Constants.selectionAnimationKey)
    }

    // MARK: Action Handlers

    @objc private func didTapSegment(_ tapRecognizer: UITapGestureRecognizer) {
        if let newIndex = segments.firstIndex(where: { $0 === tapRecognizer.view }), _selectedSegmentIndex != newIndex {
            let oldIndex = _selectedSegmentIndex
            _selectedSegmentIndex = newIndex

            animateSelectionIndexChange(oldIndex)
            updateSegmentsSelection()

            sendActions(for: .valueChanged)
        }
    }
}
