import Foundation

class TriangularedTitleMultiValueView: TitleMultiValueView {
    let backgroundView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0.0

        return view
    }()

    override func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        backgroundView.addSubview(borderView)
        borderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        backgroundView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.bottom.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        backgroundView.addSubview(valueLabelsStack)
        valueLabelsStack.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview()
            make.bottom.equalToSuperview().inset(8)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }

        valueLabelsStack.addArrangedSubview(valueTop)
        valueLabelsStack.addArrangedSubview(valueBottom)
    }
}
