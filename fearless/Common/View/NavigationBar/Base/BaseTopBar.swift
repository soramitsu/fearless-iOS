import UIKit

class BaseTopBar: UIView {
    enum ViewPosition {
        case left
        case center
        case right
    }

    private let horizontalStackView: UIStackView = UIFactory.default.createHorizontalStackView()
    private let leftStackView: UIStackView = UIFactory.default.createVerticalStackView()
    private let centerStackView: UIStackView = UIFactory.default.createVerticalStackView()
    private let rightStackView: UIStackView = UIFactory.default.createVerticalStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(horizontalStackView)
        horizontalStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        horizontalStackView.addArrangedSubview(leftStackView)
        horizontalStackView.addArrangedSubview(centerStackView)
        horizontalStackView.addArrangedSubview(rightStackView)
    }

    func setLeftViews(_ leftViews: [UIView]) {
        leftStackView.subviews.forEach { subview in
            leftStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        leftViews.forEach { view in
            leftStackView.addArrangedSubview(view)
        }
    }

    func setCenterViews(_ centerViews: [UIView]) {
        centerStackView.subviews.forEach { subview in
            centerStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        centerViews.forEach { view in
            centerStackView.addArrangedSubview(view)
        }
    }

    func setRightViews(_ rightViews: [UIView]) {
        rightStackView.subviews.forEach { subview in
            rightStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        rightViews.forEach { view in
            rightStackView.addArrangedSubview(view)
        }
    }

    func addView(_ view: UIView, position: ViewPosition) {
        switch position {
        case .left:
            leftStackView.addArrangedSubview(view)
        case .center:
            centerStackView.addArrangedSubview(view)
        case .right:
            rightStackView.addArrangedSubview(view)
        }
    }
}
