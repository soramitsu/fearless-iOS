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
        addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        addSubview(valueView)
        valueView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleView).offset(8.0)
        }
    }
}
