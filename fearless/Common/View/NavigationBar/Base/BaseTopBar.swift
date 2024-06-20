import UIKit

class BaseTopBar: UIView {
    var leftStackView: UIStackView = UIFactory.default.createHorizontalStackView(spacing: 8)
    var centerStackView: UIStackView = UIFactory.default.createHorizontalStackView()
    var rightStackView: UIStackView = UIFactory.default.createHorizontalStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(leftStackView)
        addSubview(centerStackView)
        addSubview(rightStackView)

        leftStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.top.equalTo(safeAreaLayoutGuide).offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        centerStackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide).offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.greaterThanOrEqualTo(leftStackView.snp.trailing).offset(UIConstants.defaultOffset)
        }

        rightStackView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalTo(safeAreaLayoutGuide).offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.greaterThanOrEqualTo(centerStackView.snp.trailing).offset(UIConstants.defaultOffset)
        }
    }

    func setLeftViews(_ leftViews: [UIView]) {
        leftStackView.arrangedSubviews.forEach { subview in
            leftStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        leftViews.forEach { view in
            leftStackView.addArrangedSubview(view)
        }
    }

    func setCenterViews(_ centerViews: [UIView]) {
        centerStackView.arrangedSubviews.forEach { subview in
            centerStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        centerViews.forEach { view in
            centerStackView.addArrangedSubview(view)
        }
    }

    func setRightViews(_ rightViews: [UIView]) {
        rightStackView.arrangedSubviews.forEach { subview in
            rightStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        rightViews.forEach { view in
            rightStackView.addArrangedSubview(view)
        }
    }
}
