import UIKit

final class SearchPeopleTableSectionHeaderView: UIView {
    
    private var titleLabel: UILabel = {
       let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorAlmostWhite()
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupLayout() {
        addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.trailing.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }
    }
}
