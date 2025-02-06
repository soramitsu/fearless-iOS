import UIKit

struct CrossChainStatusViewModel {
    private let status: OKXCrossChainTxStatus?
    private let detailStatus: OKXCrossChainTxDetailStatus?
    private let locale: Locale
    
    init(status: OKXCrossChainTxStatus?, detailStatus: OKXCrossChainTxDetailStatus?, locale: Locale) {
        self.status = status
        self.detailStatus = detailStatus
        self.locale = locale
    }
    
    var title: String? {
        guard let status else {
            return detailStatus?.statusDescription(locale: locale)
        }
        
        if let detailStatus, case OKXCrossChainTxDetailStatus.refund = detailStatus {
            return R.string.localizable.commonRefund(preferredLanguages: locale.rLanguages)
        }
        
        return status.rawValue.capitalized
    }
    
    var color: UIColor? {
        guard let status else {
            return detailStatus?.statusColor()
        }
        
        var result: UIColor?
        if let detailStatus, case OKXCrossChainTxDetailStatus.refund = detailStatus {
            result = R.color.warning_orange()
        }
        
        switch status {
        case .pending:
            result = R.color.warning_yellow()
        case .success:
            result = R.color.success_green()
        case .failure:
            result = R.color.error_red()
        }
        
        return result ?? R.color.colorStrokeGray()
    }
}
