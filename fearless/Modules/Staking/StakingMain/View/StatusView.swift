// import UIKit
// import SoraUI
//
// final class StatusView: UIView {
//    enum Status {
//        case active(text: String)
//        case inactive(text: String)
//        case waiting(text: String, detailsText: String)
//
//        var color: UIColor {
//            switch self {
//            case .active:
//                return R.color.colorGreen()!
//            case .inactive:
//                return R.color.colorRed()!
//            case .waiting:
//                return R.color.colorTransparentText()!
//            }
//        }
//
//        var text: String {
//            switch self {
//            case let .active(text):
//                return text
//            case let .inactive(text):
//                return text
//            case let .waiting(text, _):
//                return text
//            }
//        }
//
//        var detailsText: String? {
//            if case let .waiting(_, detailsText) = self {
//                return detailsText
//            }
//            return nil
//        }
//
//        var shouldShowDetails: Bool {
//            if case .waiting = self {
//                return false
//            }
//            return true
//        }
//    }
//
//    let indicatorView: RoundedView = {
//        let view = RoundedView()
//        view.cornerRadius = 4.0
//        return view
//    }()
//
//    let titleLabel: UILabel = {
//        let label = UILabel()
//        label.font = .capsTitle
//        return label
//    }()
//
//    let detailsLabel: UILabel = {
//        let label = UILabel()
//        label.font = .capsTitle
//        return label
//    }()
//
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//
//        setupLayout()
//    }
//
//    required init?(coder: NSCoder) {
//        super.init(coder: coder)
//
//        setupLayout()
//    }
//
//    func set(status: Status) {
//        indicatorView.backgroundColor = status.color
//        titleLabel.textColor = status.color
//        detailsLabel.textColor = status.color
//        titleLabel.text = status.text
//        detailsLabel.text = status.detailsText
//        detailsLabel.isHidden = status.shouldShowDetails
//    }
//
//    private func setupLayout() {
//        addSubview(indicatorView)
//        indicatorView.snp.makeConstraints { make in
//            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
//            make.centerY.equalToSuperview()
//            make.size.equalTo(8.0)
//        }
//
//        addSubview(titleLabel)
//        titleLabel.snp.makeConstraints { make in
//            make.leading.equalTo(indicatorView.snp.trailing).offset(8)
//            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
//            make.centerY.equalToSuperview()
//        }
//    }
// }
