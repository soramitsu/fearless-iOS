import UIKit

extension UIView {
    static func createSeparator(color: UIColor? = R.color.colorLightGray()) -> UIView {
        let view = UIView()
        view.backgroundColor = color
        return view
    }

    static func createSeparator(
        color: UIColor? = R.color.colorLightGray(),
        horizontalInset: CGFloat = 0
    ) -> UIView {
        SeparatorWithHorizontalInset(color: color, horizontalInset: horizontalInset)
    }
}

private class SeparatorWithHorizontalInset: UIView {
    init(color: UIColor?, horizontalInset: CGFloat) {
        super.init(frame: .zero)

        let separator = UIView.createSeparator(color: color)
        addSubview(separator)
        separator.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(horizontalInset)
            make.top.bottom.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
