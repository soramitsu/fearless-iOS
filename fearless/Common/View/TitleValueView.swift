import UIKit
import SoraUI

class TitleValueView: UIView {
    private enum Constants {
        static let valueImageViewSize = CGSize(width: 6, height: 12)
    }

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = UIFont.p1Paragraph
        return label
    }()

    let valueLabel: SkeletonLabel = {
        let label = SkeletonLabel(skeletonSize: CGSize(width: 70, height: 14))
        label.textColor = R.color.colorWhite()
        label.font = UIFont.p1Paragraph
        label.textAlignment = .right
        return label
    }()

    let valueImageView = UIImageView()
    let valueStackView = UIFactory.default.createHorizontalStackView(spacing: 5)

    let borderView: BorderedContainerView = {
        let view = BorderedContainerView()
        view.backgroundColor = .clear
        view.borderType = .bottom
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorDarkGray()!
        return view
    }()

    let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.hidesWhenStopped = true
        view.style = UIActivityIndicatorView.Style.medium
        return view
    }()

    var equalsLabelsWidth: Bool = false {
        didSet {
            if equalsLabelsWidth {
                valueLabel.snp.makeConstraints { make in
                    make.width.equalTo(titleLabel.snp.width)
                }
            }
        }
    }

    init(skeletonSize: CGSize = .zero) {
        super.init(frame: .zero)
        setupLayout()
        valueLabel.skeletonSize = skeletonSize
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: String?) {
        if viewModel != nil {
            activityIndicator.stopAnimating()
        } else {
            activityIndicator.startAnimating()
        }

        valueLabel.text = viewModel
    }

    private func setupLayout() {
        addSubview(borderView)
        borderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }

        valueStackView.addArrangedSubview(valueLabel)
        valueStackView.addArrangedSubview(valueImageView)
        addSubview(valueStackView)
        valueStackView.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }

        valueImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.valueImageViewSize)
        }

        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(valueStackView.snp.trailing)
        }
    }
}
