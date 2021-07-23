import UIKit
import SoraUI

class MultiValueView: UIView {
    let valueTop: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        label.textAlignment = .right
        return label
    }()

    let valueBottom: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorGray()
        label.font = .p2Paragraph
        label.textAlignment = .right
        return label
    }()

    let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.addArrangedSubview(valueTop)
        stackView.addArrangedSubview(valueBottom)
    }

    func bind(topValue: String, bottomValue: String?) {
        valueTop.text = topValue

        if let bottomValue = bottomValue {
            valueBottom.isHidden = false
            valueBottom.text = bottomValue
        } else {
            valueBottom.text = ""
            valueBottom.isHidden = true
        }
    }
}
