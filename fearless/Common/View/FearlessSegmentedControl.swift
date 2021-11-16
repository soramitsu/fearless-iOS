import UIKit

class FearlessSegmentedControl: UIView {
    private var segments: [FearlessSegmentedControlUnit] = []

    private var selectedUnit: FearlessSegmentedControlUnit?

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorAlmostWhite()
        return label
    }()

    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 0
        stackView.distribution = .fillProportionally

        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        stackView.layer.cornerRadius = bounds.size.height / 2
    }

    private func setupLayout() {
        backgroundColor = .clear
        stackView.backgroundColor = R.color.colorBonusBackground()

        addSubview(titleLabel)
        addSubview(stackView)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        stackView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.height.equalToSuperview()
            make.leading.equalTo(titleLabel.snp.trailing).offset(UIConstants.defaultOffset)
        }

        stackView.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    func addSegment(_ button: FearlessSegmentedControlUnit) {
        if selectedUnit == nil {
            selectedUnit = button
        }

        segments.append(button)
        drawCurrentState()
    }

    func removeSegment(_ button: FearlessSegmentedControlUnit) {
        if let index = segments.firstIndex(of: button) {
            segments.remove(at: index)
            drawCurrentState()
        }
    }

    func setSegments(_ buttons: [FearlessSegmentedControlUnit]) {
        if selectedUnit == nil {
            selectedUnit = buttons.first
        }

        segments = buttons
        drawCurrentState()
    }

    private func drawCurrentState() {
        stackView.arrangedSubviews.forEach {
            if let segment = $0 as? FearlessSegmentedControlUnit {
                segment.removeTarget(self, action: #selector(segmentClicked(_:)), for: .touchUpInside)
                stackView.removeArrangedSubview(segment)
                segment.removeFromSuperview()
            }
        }

        segments.forEach {
            stackView.addArrangedSubview($0)

            $0.addTarget(self, action: #selector(segmentClicked(_:)), for: .touchUpInside)
        }

        drawSelectionState()
    }

    private func drawSelectionState() {
        let unselectedSegments = segments.filter { $0 != selectedUnit }

        unselectedSegments.forEach {
            $0.backgroundColor = .clear
        }

        selectedUnit?.backgroundColor = R.color.colorAccent()
    }

    @objc private func segmentClicked(_ sender: FearlessSegmentedControlUnit) {
        selectedUnit = sender

        drawSelectionState()
    }
}
