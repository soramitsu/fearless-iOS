import UIKit
import SnapKit

class MultilineTriangularedView: UIView {
    enum Layout {
        static let verticalOffset: CGFloat = 8
        static let horizontalOffset: CGFloat = 16
    }

    private(set) var backgroundView: TriangularedView!
    private(set) var titleLabel: UILabel!
    private(set) var subtitleLabel: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.verticalOffset)
            make.leading.equalToSuperview().offset(Layout.horizontalOffset)
            make.trailing.equalToSuperview().offset(-Layout.horizontalOffset)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-Layout.verticalOffset)
            make.leading.equalToSuperview().offset(Layout.horizontalOffset)
            make.trailing.equalToSuperview().offset(-Layout.horizontalOffset)
            make.top.greaterThanOrEqualTo(titleLabel.snp.bottom)
        }
    }

    private func configure() {
        backgroundColor = .clear

        if backgroundView == nil {
            backgroundView = TriangularedView()
            backgroundView.isUserInteractionEnabled = false
            addSubview(backgroundView)
        }

        if titleLabel == nil {
            titleLabel = UILabel()
            addSubview(titleLabel)
        }

        if subtitleLabel == nil {
            subtitleLabel = UILabel()
            subtitleLabel.numberOfLines = 0
            addSubview(subtitleLabel)
        }
    }
}
