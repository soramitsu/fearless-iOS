import UIKit
import SoraUI

class TitleStatusView: UIView {
    enum Mode {
        case indicatorTile
        case titleIndicator
    }

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    let indicatorView: RoundedView = {
        let view = RoundedView()
        view.cornerRadius = 4.0
        return view
    }()

    var indicatorColor: UIColor {
        get {
            indicatorView.fillColor
        }

        set {
            indicatorView.fillColor = newValue
        }
    }

    var mode: Mode = .titleIndicator {
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
        view.spacing = 12.0
        view.alignment = .center
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

        indicatorView.snp.makeConstraints { make in
            make.height.width.equalTo(2 * indicatorView.cornerRadius)
        }

        applyLayout()
    }

    private func applyLayout() {
        titleLabel.removeFromSuperview()
        indicatorView.removeFromSuperview()

        switch mode {
        case .titleIndicator:
            stackView.addArrangedSubview(titleLabel)
            stackView.addArrangedSubview(indicatorView)
        case .indicatorTile:
            stackView.addArrangedSubview(indicatorView)
            stackView.addArrangedSubview(titleLabel)
        }
    }
}
