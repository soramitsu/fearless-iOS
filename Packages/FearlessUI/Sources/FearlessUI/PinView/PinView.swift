/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit
import AudioToolbox

// swiftlint:disable type_body_length file_length

public protocol PinViewDelegate: AnyObject {
    /**
     *  Called when current input field becomes filled.
     *  - parameters:
     *      - pinView: current input pin view
     *      - result: string entered by the user
     */
    func didCompleteInput(pinView: PinView, result: String)

    /**
     *  Called when state in create mode changes.
     *  - parameters:
     *      - pinView: current input pin view
     *      - state: previous state
     */
    func didChange(pinView: PinView, from state: PinView.CreationState)

    /**
     *  Called when user selects accessory control.
     *  - parameters:
     *      - pinView: current input pin view
     */
    func didSelectAccessoryControl(pinView: PinView)

    /**
     *  Called on wrong confirmation of pin.
     *  - parameters:
     *      - pinView: current input pin view
     */
    func didFailConfirmation(pinView: PinView)
}

public protocol PinViewAccessibilitySupportProtocol: AnyObject {
    func setupInputField(accessibilityId: String?)
}

/**
 *  Subclass of UIView designed to provide pincode input interface. There are 3 modes in which the view
 *  can exist. `Create` mode can be used to setup pincode whereas `securedInput` and `unsecuredInput` to request
 *  pincode from the user. Style of numpad keyboard and input field can be changed by modifing properties of
 *  `numpadView`, `characterFieldsView` and `securedCharacterFieldsView` correspondingly.
 */
open class PinView: UIView {
    public enum Mode: Int8 {
        case create = 0
        case securedInput = 1
        case unsecuredInput = 2
    }

    public enum CreationState {
        case normal
        case confirm
    }

    /// Returns current fields view depending on mode and creation state
    public var activeFieldsView: CharacterFieldsViewProtocol {
        switch mode {
        case .create:
            return securedCharacterFieldsView!
        case .securedInput:
            return securedCharacterFieldsView!
        case .unsecuredInput:
            return characterFieldsView!
        }
    }

    /// Field view which is used in `create` and `unsecuredInput` modes.
    public private(set) weak var characterFieldsView: CharacterFieldsView?

    /// Field view which is used in `securedInput` mode.
    public private(set) weak var securedCharacterFieldsView: SecuredCharacterFieldsView?

    /**
     *  Customize properties of this view directly to provide new style for numpad. Delegate property **must not**
     *  be changed.
     */
    public private(set) var numpadView: NumpadView?

    /// State of the in `create` mode. This value is ignored for other modes.
    public private(set) var creationState = CreationState.normal

    /**
     *  Use `create` mode to request pin setup and `unsecuredInput` or `securedInput`
     *  to request pin enter from the user. By default `unsecuredInput`.
     */
    public var mode = Mode.unsecuredInput {
        didSet {
            if oldValue != mode {
                clearCreationState()
                clearRedundantFieldsView()
                createFieldsViewsIfNeeded()
                invalidateLayout()
            }
        }
    }

    /// Spacing between numpad and input field. By default `20.0`
    public var verticalSpacing: CGFloat = 20.0 {
        didSet {
            invalidateLayout()
        }
    }

    /// By default `0.5`
    public var errorAnimationDuration: CGFloat = 0.5

    /// By default `20.0`
    public var errorAnimationAmplitude: CGFloat = 20.0

    /// By default `0.4`
    public var errorAnimationDamping: CGFloat = 0.4

    /// By default `1.0`
    public var errorAnimationInitialVelocity: CGFloat = 1.0

    /// By default `.curveEaseInOut`
    public var errorAnimationAnimationOptions: UIView.AnimationOptions = .curveEaseInOut

    /// Provide delegate to received callbacks about changes in the view.
    public weak var delegate: PinViewDelegate?

    // MARK: Private

    private weak var animationView: UIView?

    private var createdCharacters: [Character]?

    // MARK: Public Interface

    /**
     *  Call this method to start pincode creation from the begining.
     *  - parameters:
     *      - animated: flag states whether transition should be animated
     */
    public func resetCreationState(animated: Bool) {
        guard mode == .create else { return }

        if let securedCharacterFieldsView = securedCharacterFieldsView {
            securedCharacterFieldsView.clear()
        }

        if creationState == .confirm {
            clearCreationState()
            switchToNormalState(animated: animated)
        }
    }

    /**
     *  Call this method to reset current input field.
     *  - parameters:
     *      - shouldAnimateError: flag states whether animation about wrong pincode must be applied
     */
    public func reset(shouldAnimateError: Bool) {
        if let characterFieldsView = characterFieldsView {
            characterFieldsView.clear()
        }

        if let securedCharacterFieldsView = securedCharacterFieldsView {
            securedCharacterFieldsView.clear()
        }

        if shouldAnimateError {
            animateWrongInputError()
        }
    }

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

    /**
        Override this method to provided additional configuration logic.
        This method is **not supposed** to be called directly.
    */
    open func configure() {
        self.backgroundColor = UIColor.clear

        createAnimationViewIfNeeded()
        createFieldsViewsIfNeeded()
        createNumpadViewIfNeeded()
    }

    private func createFieldsViewsIfNeeded() {
        switch mode {
        case .create:
            createSecuredFieldsViewIfNeeded()
            securedCharacterFieldsView!.alpha = 1.0
        case .securedInput:
            createSecuredFieldsViewIfNeeded()
            securedCharacterFieldsView!.alpha = 1.0
        case .unsecuredInput:
            createCharacterFieldsViewIfNeeded()
            characterFieldsView!.alpha = 1.0
        }
    }

    private func createAnimationViewIfNeeded() {
        if animationView == nil {
            let animationView = UIView()
            animationView.backgroundColor = UIColor.clear
            addSubview(animationView)
            self.animationView = animationView
        }
    }

    private func createCharacterFieldsViewIfNeeded() {
        if characterFieldsView == nil {
            let fieldsView = CharacterFieldsView()
            animationView!.addSubview(fieldsView)
            self.characterFieldsView = fieldsView
        }
    }

    private func createSecuredFieldsViewIfNeeded() {
        if securedCharacterFieldsView == nil {
            let fieldsView = SecuredCharacterFieldsView()
            animationView!.addSubview(fieldsView)
            self.securedCharacterFieldsView = fieldsView
        }
    }

    private func createNumpadViewIfNeeded() {
        if numpadView == nil {
            let numpadView = NumpadView()
            numpadView.delegate = self
            addSubview(numpadView)
            self.numpadView = numpadView
        }
    }

    private func clearRedundantFieldsView() {
        if let charaterFieldsView = characterFieldsView, mode != .unsecuredInput {
            charaterFieldsView.removeFromSuperview()
            self.characterFieldsView = nil
        }

        if let securedFieldsView = securedCharacterFieldsView, mode == .unsecuredInput {
            securedFieldsView.removeFromSuperview()
            self.securedCharacterFieldsView = nil
        }
    }

    private func clearCreationState() {
        createdCharacters = nil
        creationState = .normal
    }

    // MARK: Layout
    open override var intrinsicContentSize: CGSize {
        var contentSize = CGSize.zero

        if let characterFieldsView = characterFieldsView {
            let size = characterFieldsView.intrinsicContentSize
            contentSize.width = max(size.width, contentSize.width)
            contentSize.height = max(size.height, contentSize.height)
        }

        if let securedFieldsView = securedCharacterFieldsView {
            let size = securedFieldsView.intrinsicContentSize
            contentSize.width = max(size.width, contentSize.width)
            contentSize.height = max(size.height, contentSize.height)
        }

        contentSize.height += CGFloat(verticalSpacing)

        if let numpadView = numpadView {
            let size = numpadView.intrinsicContentSize
            contentSize.width = max(size.width, contentSize.width)
            contentSize.height += size.height
        }

        return contentSize
    }

    open func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    open override func layoutSubviews() {
        super.layoutSubviews()

        layoutAnimationView()
        layoutCharacterFieldsView()
        layoutSecuredFieldsView()
        layoutNumpadView()
    }

    private func layoutAnimationView() {
        if let animationView = animationView {
            animationView.frame = self.bounds
        }
    }

    private func layoutCharacterFieldsView() {
        if let characterFieldsView = characterFieldsView {
            let viewSize = characterFieldsView.intrinsicContentSize
            let contentSize = self.intrinsicContentSize
            let originX = self.bounds.midX - viewSize.width / 2.0
            let originY = self.bounds.midY - contentSize.height / 2.0

            characterFieldsView.frame = CGRect(origin: CGPoint(x: originX, y: originY), size: viewSize)
        }
    }

    private func layoutSecuredFieldsView() {
        if let securedCharacterFieldsView = securedCharacterFieldsView {
            let viewSize = securedCharacterFieldsView.intrinsicContentSize
            let contentSize = self.intrinsicContentSize
            let originX = self.bounds.midX - viewSize.width / 2.0
            let originY = self.bounds.midY - contentSize.height / 2.0

            securedCharacterFieldsView.frame = CGRect(origin: CGPoint(x: originX, y: originY), size: viewSize)
        }
    }

    private func layoutNumpadView() {
        if let numpadView = numpadView {
            let viewSize = numpadView.intrinsicContentSize
            let contentSize = self.intrinsicContentSize

            let originX = self.bounds.midX - viewSize.width / 2.0
            let originY = self.bounds.midY + contentSize.height / 2.0 - viewSize.height

            numpadView.frame = CGRect(origin: CGPoint(x: originX, y: originY), size: viewSize)
        }
    }

    // Fields View Processing

    private func didCompleteInput() {
        switch mode {
        case .create:
            handleCreationInputCompletion()
        case .securedInput:
            notifyDelegateOnCompletion()
        case .unsecuredInput:
            notifyDelegateOnCompletion()
        }
    }

    private func handleCreationInputCompletion() {
        switch creationState {
        case .normal:
            creationState = .confirm
            createdCharacters = securedCharacterFieldsView!.characters

            switchToConfirmationState(animated: true)
            notifyDelegateOnStateChange(from: .normal)
        case .confirm:
            if securedCharacterFieldsView!.characters != createdCharacters {
                animateWrongInputError()
                securedCharacterFieldsView!.clear()
                notifyDelegateOnWrongInputError()
            } else {
                notifyDelegateOnCompletion()
            }
        }
    }

    private func switchToConfirmationState(animated: Bool) {
        if let securedCharacterFieldsView = securedCharacterFieldsView {
            securedCharacterFieldsView.clear()

            if animated {
                let animation = CATransition()
                animation.type = CATransitionType.push
                animation.subtype = CATransitionSubtype.fromRight
                animationView?.layer.add(animation, forKey: "state.confirm")
            }
        }
    }

    private func switchToNormalState(animated: Bool) {
        if let securedCharacterFieldsView = securedCharacterFieldsView {
            securedCharacterFieldsView.clear()

            if animated {
                let animation = CATransition()
                animation.type = CATransitionType.push
                animation.subtype = CATransitionSubtype.fromLeft
                animationView?.layer.add(animation, forKey: "state.normal")
            }
        }
    }

    private func animateWrongInputError() {
        if let animationView = animationView {
            animationView.transform = CGAffineTransform(translationX: errorAnimationAmplitude, y: 0)
            UIView.animate(withDuration: TimeInterval(errorAnimationDuration),
                           delay: 0,
                           usingSpringWithDamping: errorAnimationDamping,
                           initialSpringVelocity: errorAnimationInitialVelocity,
                           options: errorAnimationAnimationOptions,
                           animations: {
                animationView.transform = CGAffineTransform.identity
            }, completion: nil)

            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
    }

    // MARK: Delegate Handling

    private func notifyDelegateOnCompletion() {
        self.delegate?.didCompleteInput(pinView: self, result: String(activeFieldsView.allCharacters()))
    }

    private func notifyDelegateOnStateChange(from state: CreationState) {
        self.delegate?.didChange(pinView: self, from: state)
    }

    private func notifyDelegateOnWrongInputError() {
        self.delegate?.didFailConfirmation(pinView: self)
    }
}

extension PinView: NumpadViewDelegate {
    public func numpadView(_ view: NumpadView, didSelectNumAt index: Int) {
        guard !activeFieldsView.isComplete else {
            didCompleteInput()
            return
        }

        activeFieldsView.append(character: Character(String(index)))

        if activeFieldsView.isComplete {
            didCompleteInput()
        }
    }

    public func numpadViewDidSelectBackspace(_ view: NumpadView) {
        if !activeFieldsView.isEmpty {
            activeFieldsView.removeLastCharacter()
        }
    }

    public func numpadViewDidSelectAccessoryControl(_ view: NumpadView) {
        delegate?.didSelectAccessoryControl(pinView: self)
    }
}

extension PinView: PinViewAccessibilitySupportProtocol {
    public func setupInputField(accessibilityId: String?) {
        guard let inputFieldView = activeFieldsView as? UIView else {
            return
        }

        inputFieldView.accessibilityIdentifier = accessibilityId
    }
}

// swiftlint:enable type_body_length file_length
