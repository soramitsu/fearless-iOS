import UIKit
import SoraUI

class IconDetailsView: UIView {
    enum Mode {
        case iconDetails
        case detailsIcon
    }

    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        return imageView
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = UIFont.p2Paragraph
        label.numberOfLines = 0
        return label
    }()

    var mode: Mode = .iconDetails {
        didSet {
            applyLayout()
        }
    }

    var spacing: CGFloat {
        get {
            stackView.spacing
        }

        set {
            stackView.spacing = newValue
        }
    }

    private var stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.spacing = 8.0
        view.alignment = .center
        return view
    }()

    var iconWidth: CGFloat = 16.0 {
        didSet {
            imageView.snp.updateConstraints { make in
                make.width.equalTo(iconWidth)
            }

            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        guard imageView.superview == nil else {
            return
        }

        setupLayout()
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        imageView.snp.makeConstraints { make in
            make.width.equalTo(iconWidth)
        }

        applyLayout()
    }

    private func applyLayout() {
        imageView.removeFromSuperview()
        detailsLabel.removeFromSuperview()

        switch mode {
        case .iconDetails:
            stackView.addArrangedSubview(imageView)
            stackView.addArrangedSubview(detailsLabel)
        case .detailsIcon:
            stackView.addArrangedSubview(detailsLabel)
            stackView.addArrangedSubview(imageView)
        }
    }
}
