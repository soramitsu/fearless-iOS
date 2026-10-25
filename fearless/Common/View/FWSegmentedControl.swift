import UIKit

protocol FWSegmentedControlDelegate: AnyObject {
    func didSelect(_ segmentIndex: Int)
}

final class FWSegmentedControl: UIControl {
    // MARK: - Public properties

    weak var delegate: FWSegmentedControlDelegate?
    private(set) var selectedSegmentIndex: Int = 0

    var defaultFont: UIFont = .p1Paragraph {
        didSet {
            updateLabelsFont(with: defaultFont, selected: false)
        }
    }

    var highlightFont: UIFont = .h5Title {
        didSet {
            updateLabelsFont(with: highlightFont, selected: true)
        }
    }

    var sliderAnimationDuration: TimeInterval {
        0.2
    }

    // MARK: - Private properties

    private let containerView: TriangularedView = {
        let containerView = TriangularedView()
        containerView.fillColor = R.color.colorWhite8()!
        containerView.highlightedFillColor = R.color.colorWhite8()!
        containerView.shadowOpacity = 0
        return containerView
    }()

    private let backgroundView = UIView()
    private let selectedContainerView = UIView()
    private let sliderView = SliderView()

    private var segments: [String] = []
    private var wrapsTitles = false
    private var measuredHeight: CGFloat = 0

    func configureWrapping(locale: Locale, traits: UITraitCollection) {
        wrapsTitles = true
        isAccessibilityElement = false
        defaultFont = .fw(.bodyM, locale: locale, compatibleWith: traits)
        highlightFont = .fw(.titleS, locale: locale, compatibleWith: traits)
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        guard wrapsTitles else { return super.intrinsicContentSize }
        let width = max(1, bounds.width / CGFloat(max(1, numberOfSegments)) - 16)
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        let heights = segments.flatMap { title in
            [defaultFont, highlightFont].map { font -> CGFloat in
                label.text = title
                label.font = font
                return label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
            }
        }
        return CGSize(width: UIView.noIntrinsicMetric, height: max(44, ceil(heights.max() ?? 0) + 20))
    }

    private var numberOfSegments: Int {
        segments.count
    }

    private var segmentWidth: CGFloat {
        numberOfSegments > 0 ? backgroundView.bounds.width / CGFloat(numberOfSegments) : 0
    }

    private var startPosition: CGFloat = 0

    // MARK: - Lifecycle

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setupLayout()
        setupSegments()
        if wrapsTitles {
            let height = intrinsicContentSize.height
            if measuredHeight != height {
                measuredHeight = height
                invalidateIntrinsicContentSize()
            }
        }
    }

    // MARK: Public methods

    func setSegmentItems(_ segments: [String]) {
        guard
            segments.isNotEmpty,
            segments.count > 1
        else {
            fatalError("Segments array cannot be empty")
        }

        self.segments = segments
        selectedSegmentIndex = min(selectedSegmentIndex, segments.count - 1)
        setupSegments()
        if wrapsTitles { invalidateIntrinsicContentSize() }
        setNeedsLayout()
    }

    // MARK: - Setup

    private func setup() {
        setupAutoresizingMasks()
        addTapGesture()
        addDragGesture()
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.frame = bounds
        let frame = containerView.bounds

        containerView.addSubview(backgroundView)
        backgroundView.frame = frame

        containerView.addSubview(selectedContainerView)
        selectedContainerView.frame = frame
        selectedContainerView.layer.mask = sliderView.sliderMaskView.layer
        selectedContainerView.backgroundColor = R.color.colorWhite16()

        containerView.addSubview(sliderView)
        sliderView.frame = CGRect(
            x: CGFloat(selectedSegmentIndex) * segmentWidth,
            y: 0,
            width: segmentWidth,
            height: backgroundView.frame.height
        )
    }

    private func setupSegments() {
        clearSegments()

        segments.enumerated().forEach { index, segmentTitle in
            let selected = selectedSegmentIndex == index
            let defaultLabel = createLabel(
                with: segmentTitle,
                at: index,
                selected: selected
            )

            backgroundView.addSubview(defaultLabel)
        }
        if wrapsTitles { updateAccessibility() }
    }

    private func setupAutoresizingMasks() {
        containerView.autoresizingMask = [.flexibleWidth]
        backgroundView.autoresizingMask = [.flexibleWidth]
        selectedContainerView.autoresizingMask = [.flexibleWidth]
        sliderView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleWidth]
    }

    private func clearSegments() {
        backgroundView.subviews.forEach { $0.removeFromSuperview() }
        selectedContainerView.subviews.forEach { $0.removeFromSuperview() }
    }

    private func createLabel(with text: String, at index: Int, selected: Bool) -> UILabel {
        let rect = CGRect(
            x: CGFloat(index) * segmentWidth,
            y: 0,
            width: segmentWidth,
            height: backgroundView.frame.height
        )
        let label = UILabel(frame: wrapsTitles ? rect.insetBy(dx: 8, dy: 0) : rect)
        if wrapsTitles {
            label.numberOfLines = 0
            label.lineBreakMode = .byCharWrapping
        }
        label.text = text
        label.textAlignment = .center
        label.font = selected ? highlightFont : defaultFont
        return label
    }

    private func updateLabelsFont(with font: UIFont, selected: Bool) {
        let containerView = selected ? selectedContainerView : backgroundView
        containerView.subviews.forEach { ($0 as? UILabel)?.font = font }
    }

    // MARK: - Tap gestures

    private func addTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
    }

    private func addDragGesture() {
        let drag = UIPanGestureRecognizer(target: self, action: #selector(didPan))
        sliderView.addGestureRecognizer(drag)
    }

    @objc private func didTap(tapGesture: UITapGestureRecognizer) {
        moveToNearestPoint(basedOn: tapGesture)
    }

    @objc private func didPan(panGesture: UIPanGestureRecognizer) {
        switch panGesture.state {
        case .began:
            startPosition = panGesture.location(in: sliderView).x - sliderView.frame.width / 2

        case .changed:
            let location = panGesture.location(in: self)
            sliderView.center.x = location.x - startPosition

        default:
            moveToNearestPoint(basedOn: panGesture, velocity: panGesture.velocity(in: sliderView))
        }
    }

    // MARK: - Slider position

    private func moveToNearestPoint(basedOn gesture: UIGestureRecognizer, velocity: CGPoint? = nil) {
        guard numberOfSegments > 0, sliderView.bounds.width > 0 else { return }
        var location = gesture.location(in: self)
        if let velocity = velocity {
            let offset = velocity.x / 13
            location.x += offset
        }
        let index = segmentIndex(for: location)
        move(to: index)
        delegate?.didSelect(index)
    }

    private func move(to index: Int) {
        let correctOffset = center(at: index)
        animate(to: correctOffset)

        selectedSegmentIndex = index
        setupSegments()
    }

    private func segmentIndex(for point: CGPoint) -> Int {
        var index = Int(point.x / sliderView.frame.width)
        if index < 0 { index = 0 }
        if index > numberOfSegments - 1 { index = numberOfSegments - 1 }
        return index
    }

    private func center(at index: Int) -> CGFloat {
        let xOffset = CGFloat(index) * sliderView.frame.width + sliderView.frame.width / 2
        return xOffset
    }

    private func animate(to position: CGFloat) {
        UIView.animate(withDuration: sliderAnimationDuration) {
            self.sliderView.center.x = position
        }
    }

    // MARK: - Helper view

    class SliderView: UIView {
        fileprivate let sliderMaskView = TriangularedView()

        override var frame: CGRect {
            didSet {
                sliderMaskView.frame = frame
            }
        }

        override var center: CGPoint {
            didSet {
                sliderMaskView.center = center
            }
        }

        init() {
            super.init(frame: .zero)
            setup()
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            setup()
        }

        private func setup() {
            sliderMaskView.shadowOpacity = 0
        }
    }
}

private extension FWSegmentedControl {
    func updateAccessibility() {
        accessibilityElements = segments.enumerated().map { index, title in
            let element = ReceiveSegmentAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = title
            element.accessibilityTraits = selectedSegmentIndex == index ? [.button, .selected] : [.button]
            if !isEnabled { element.accessibilityTraits.insert(.notEnabled) }
            element.accessibilityFrameInContainerSpace = CGRect(
                x: CGFloat(index) * segmentWidth, y: 0, width: segmentWidth, height: bounds.height
            )
            element.activation = { [weak self] in
                guard let self, self.isEnabled, !self.isHidden, self.isUserInteractionEnabled else { return false }
                self.move(to: index)
                self.delegate?.didSelect(index)
                return true
            }
            return element
        }
    }
}

private final class ReceiveSegmentAccessibilityElement: UIAccessibilityElement {
    var activation: (() -> Bool)?
    override func accessibilityActivate() -> Bool { activation?() ?? false }
}
