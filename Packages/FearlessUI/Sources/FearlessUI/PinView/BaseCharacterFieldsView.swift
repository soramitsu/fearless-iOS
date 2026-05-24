/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public protocol CharacterFieldsViewProtocol: AnyObject {
    var numberOfCharacters: Int { get set }
    var isComplete: Bool { get }
    var isEmpty: Bool { get }

    func clear()
    func set(newCharacters: [Character])
    func append(character: Character)
    func removeLastCharacter()
    func allCharacters() -> [Character]
}

open class BaseCharacterFieldsView: UIView, CharacterFieldsViewProtocol {
    open var numberOfCharacters: Int = 4 {
        didSet {
            adjustCharactersList()
            invalidateLayout()
            setNeedsDisplay()
        }
    }

    open var fieldSize: CGSize = CGSize(width: 20.0, height: 20.0) {
        didSet {
            invalidateLayout()
            setNeedsDisplay()
        }
    }

    open var fieldSpacing: CGFloat = 8.0 {
        didSet {
            invalidateLayout()
            setNeedsDisplay()
        }
    }

    private(set) public var characters: [Character] = [Character]()

    // MARK: Initialize

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    // MARK: Configure

    open func configure() {
        self.backgroundColor = UIColor.clear
    }

    // MARK: Layout
    open override var intrinsicContentSize: CGSize {
        let width = CGFloat(numberOfCharacters) * fieldSize.width + CGFloat(numberOfCharacters - 1) * fieldSpacing
        let height = fieldSize.height
        return CGSize(width: width, height: height)
    }

    open func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    // MARK: Characters List

    private func adjustCharactersList() {
        if characters.count > numberOfCharacters {
            characters.removeSubrange(numberOfCharacters...)
        }
    }
}

extension BaseCharacterFieldsView {
    public var isComplete: Bool {
        return characters.count == numberOfCharacters
    }

    public var isEmpty: Bool {
        return characters.count == 0
    }

    public func clear() {
        characters.removeAll()
        setNeedsDisplay()
    }

    public func set(newCharacters: [Character]) {
        let count = min(newCharacters.count, numberOfCharacters)
        characters = Array(newCharacters[..<count])
        setNeedsDisplay()
    }

    public func append(character: Character) {
        if characters.count < numberOfCharacters {
            characters.append(character)
            setNeedsDisplay()
        }
    }

    public func removeLastCharacter() {
        if characters.count > 0 {
            characters.removeLast()
            setNeedsDisplay()
        }
    }

    public func allCharacters() -> [Character] {
        return characters
    }
}
