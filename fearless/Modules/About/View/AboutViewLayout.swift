import UIKit
import SoraUI

final class AboutViewLayout: UIView {
    // MARK: - UI

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconFearlessBig()
        return imageView
    }()

    private let aboutTitle: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let gradientView: GradientView = {
        let gradient = GradientView()
        gradient.startColor = .clear
        return gradient
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = R.color.colorBlack()
        view.separatorColor = R.color.colorDarkGray()
        view.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: UIConstants.bigOffset,
            right: 0
        )
        return view
    }()

    // MARK: - Locale

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    func applyLocalization() {
        aboutTitle.text = R.string.localizable.aboutTitle(preferredLanguages: locale.rLanguages)
    }

    // MARK: - Constructors

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let gradientContainer = UIView()
        gradientContainer.backgroundColor = .clear
        addSubview(gradientContainer)
        gradientContainer.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }

        gradientContainer.addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        gradientContainer.addSubview(logoImageView)
        logoImageView.snp.makeConstraints { make in
            make.width.equalTo(142)
            make.height.equalTo(61)
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(88)
        }

        gradientContainer.addSubview(aboutTitle)
        aboutTitle.snp.makeConstraints { make in
            make.top.equalTo(logoImageView.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().offset(-UIConstants.bigOffset)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(gradientContainer.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
