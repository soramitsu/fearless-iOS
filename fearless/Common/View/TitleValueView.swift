import UIKit
import SoraUI

final class TitleValueView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = UIFont.p1Paragraph
        return label
    }()

    let valueLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = UIFont.p1Paragraph
        label.textAlignment = .right
        return label
    }()

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
        view.style = .white
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
            make.leading.centerY.equalToSuperview()
        }

        addSubview(valueLabel)
        valueLabel.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }

        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(valueLabel.snp.trailing)
        }
    }
}
