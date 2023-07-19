//
//  UICollectionView+Reuse.swift
//  fearless
//
//  Created by Soramitsu on 14.07.2023.
//  Copyright © 2023 Soramitsu. All rights reserved.
//

import Foundation
import UIKit

extension UICollectionView {
    func registerClassForCell(_ cellClass: UICollectionViewCell.Type) {
        register(cellClass, forCellWithReuseIdentifier: cellClass.reuseIdentifier)
    }

    func dequeueReusableCellWithType<T: UICollectionViewCell>(
        _ cellClass: T.Type,
        forIndexPath indexPath: IndexPath
    ) -> T {
        guard let cell = dequeueReusableCell(
            withReuseIdentifier: cellClass.reuseIdentifier,
            for: indexPath
        ) as? T else {
            fatalError("You are trying to dequeue \(cellClass) which is not registered")
        }
        return cell
    }
}

extension UICollectionViewCell {
    var usedCollectionView: UICollectionView? {
        next(of: UICollectionView.self)
    }

    var indexPath: IndexPath? {
        usedCollectionView?.indexPath(for: self)
    }
}
