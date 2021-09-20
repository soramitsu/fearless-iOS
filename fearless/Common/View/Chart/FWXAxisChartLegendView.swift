import UIKit

/// Contains X axis chart labels
final class FWXAxisChartLegendView: UIView {
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.alignment = .center
        stackView.distribution = .equalCentering
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(stackView)
        stackView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValues(_ values: [String]) {
        stackView.subviews.forEach { $0.removeFromSuperview() }
        let labels = values.map { createLabel(text: $0) }
        labels.forEach { stackView.addArrangedSubview($0) }
    }

    private func createLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 9, weight: .semibold)
        label.textColor = R.color.colorStrokeGray()!
        return label
    }
}
