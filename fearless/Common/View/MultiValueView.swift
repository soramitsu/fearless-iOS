import UIKit
import SoraUI

class MultiValueView: UIView {
    let valueTop: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    let valueBottom: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorGray()
        label.font = .p2Paragraph
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let topSize = valueTop.intrinsicContentSize
        let bottomSize = valueBottom.intrinsicContentSize

        let height = topSize.height + bottomSize.height
        let width = max(topSize.width, bottomSize.width)

        return CGSize(width: width, height: height)
    }

    private func setupLayout() {
        addSubview(valueTop)
        valueTop.snp.makeConstraints { make in
            make.trailing.leading.equalToSuperview()
            make.bottom.equalTo(self.snp.centerY)
        }

        addSubview(valueBottom)
        valueBottom.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(self.snp.centerY)
        }
    }
}
