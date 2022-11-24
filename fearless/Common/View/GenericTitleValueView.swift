import UIKit

class GenericTitleValueView<T: UIView, V: UIView>: UIView {
    let titleView: T
    let valueView: V

    init(titleView: T = T(), valueView: V = V()) {
        self.titleView = titleView
        self.valueView = valueView

        super.init(frame: .zero)

        setup()
    }

    override init(frame: CGRect) {
        titleView = T()
        valueView = V()

        super.init(frame: frame)

        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let height = max(titleView.intrinsicContentSize.height, valueView.intrinsicContentSize.height)
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    private func setup() {
        let commonStackView = UIFactory.default.createHorizontalStackView(spacing: 8)
        addSubview(commonStackView)
        commonStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        commonStackView.addArrangedSubview(titleView)
        commonStackView.addArrangedSubview(valueView)
    }
}
