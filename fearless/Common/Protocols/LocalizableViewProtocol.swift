import UIKit

protocol LocalizableViewProtocol {
    var locale: Locale { get set }
}

typealias LocalizableView = UIView & LocalizableViewProtocol
