/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

/**
 *  Protocol designed to provide interface for input handling in order incapsulate
 *  such logic as filtering and preprocessing.
 */

public protocol InputHandling {
    /// Returns ```true``` if current value is valid otherwise ```false```.
    var completed: Bool { get }

    /**
     *  Returns ```true``` if current value required to be valid.
     *
     *  This flag is simplifies logic when current view model is part of a form (set of input view models)
     *  but it is not required for the view model to be valid so that the whole form is valid. Usually a client
     *  just ignores value of not required view models in case ```completed``` property returns ```false```.
     */

    var required: Bool { get }

    /// Current input value

    var value: String { get }

    /**
     *  Implementation of the protocol can include normalization logic that converts input value
     *  to final one. This normalization also must be applied before determining whether input is completed.
     *  Example of normalization can be trimming.
     */

    var normalizedValue: String { get }

    /**
     *  Flag that state whether current value can be changed via ```didReceiveReplacement``` method.
     *
     *  - note:
     *  This flag has no effect to ```changeValue``` and ```clearValue``` methods.
     */

    var enabled: Bool { get }

    /**
     *  This method is expected to be called from
     *  ```textField(_:shouldChangeCharactersIn:replacementString)``` delegate method of UITextField or
     *  cooresponding delegate method of UITextView.
     *
     *  - parameters:
     *     - string: String to replace provided range with;
     *     - range: Range to replace in current value;
     *
     *  - returns:
     *  ```True``` if changes were successfully applied and ```false``` otherwise.
     *
     *  - Example: A client must update the text of input field in case
     *  the call returs ```false``` and also return ```false``` from the delegate method.
     *
     *    ````
     *    func textField(_ textField: UITextField,
     *                       shouldChangeCharactersIn range: NSRange,
     *                       replacementString string: String) -> Bool {
     *        if !model.didReceiveReplacement(string, for: range) {
     *           textField.text = model.value
     *           return false
     *        }
     *       return true
     *     }
     *    ````
     */

    func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool

    /**
     *  Changes current input value to new one.
     *
     *  - parameters:
     *      - newValue: New value to replace current value with.
     */

    func changeValue(to newValue: String)

    /**
     *  Sets current value as empty string
     */

    func clearValue()

    /**
     *  Adds new observer to track value changes if it doesn't alredy exist.
     */

    func addObserver(_ observer: InputHandlingObserver)

    /**
     *  Removes observer from tracking value changes.
     */

    func removeObserver(_ observer: InputHandlingObserver)
}

/**
 *  Implementation of InputHandling that allows:
 *  - filter invalid characters;
 *  - normalize client's input (modifying final output but not changing displayed value);
 *  - preprocess client's input (modifying input value before display such as formatting);
 *
 *  See corresponding properties for more details.
 *
 *  Typical usage by a client is the following:
 *
 *  ````
 *    func textField(_ textField: UITextField,
 *                       shouldChangeCharactersIn range: NSRange,
 *                       replacementString string: String) -> Bool {
 *        if !inputHandler.didReceiveReplacement(string, for: range) {
 *           textField.text = inputHandler.value
 *           return false
 *        }
 *       return true
 *     }
 *
 *     ...
 *
 *    @objc func actionTextFieldChange(sender: UITextField) {
 *      if sender.text != inputHandler.value {
 *          sender.text = inputHandler.value
 *      }
 *    }
 *   ````
 *
 *  - note: It is crucial to check whether text changed as expected using ```actionTextFieldChange``` like
 *  method to process ```.editingChanged``` control event to handle unexpected changes in input text, for example,
 *  introduced by 'swipe to input' feature on iOS 13 or by Japanese (Romaji) keyboard.
 *  However the implemetation can be vise verse:
 *  input handler's value can be updated using ```changeValue``` method.
 *  So the main idea is just to keep ```UITextField.text``` and ```value``` sources consistent.
 */

public final class InputHandler: InputHandling {
    public private(set) var value: String {
        didSet {
            observers.forEach { $0.observer?.didChangeInputValue(self, from: oldValue) }
        }
    }

    public let enabled: Bool
    public let required: Bool

    private var observers: [InputHandlingObserverWrapper] = []

    /// Invalid character set to filter in ```didReceiveReplacement``` method.
    public let invalidCharacterSet: CharacterSet?

    /**
     *  Maximum number of characters value can contain.
     *
     *  - note:
     *  Restriction is only applied in ```didReceiveReplacement``` method. So make sure that
     *  the value takes into account constraints when changed via ```changeValue``` method.
     */

    public let maxLength: Int

    /**
    *  Minimum number of characters value can contain.
    *
    *  - note:
    *  The restriction is only inforced in ```didReceiveReplacement``` method. So make sure that
    *  the value takes into account constraints when changed via ```changeValue``` method.
    */

    public let minLength: Int

    /**
     *  Predicate to validate current value.
     */

    public let predicate: NSPredicate?

    /**
     *  Preprocesses final input value in ```didReceiveReplacement``` method befor replacement of
     *  current value.
     *
     *  - note:
     *  Current value is preprocessed by ```normalizer``` before validation.
     */
    public let processor: TextProcessing?

    /**
    *  Preprocesses final input value before checking its validity.
    */
    public let normalizer: TextProcessing?

    public var normalizedValue: String {
        if let normalizer = normalizer {
            return normalizer.process(text: value)
        } else {
            return value
        }
    }

    /**
     *  - Parameters:
     *      - value: Initial value to start input from. By default is **empty string**.
     *      - required: Flag that states whether it is required for value to be valid
     *      for the whole form to be valid. By default is **true**.
     *      - enabled: Flag that states whether a client can input to the field. Only
     *      ```didReceiveReplacement``` method is affected.
     *      - minLength: Minimum number of characters for input value to be valid. If provided parameter is
     *      less than initial input value length then the last one is set. By default is **0**.
     *      - maxLength: Minimum number of characters for input value to be valid. If provided parameter is
     *      greater than initial input value length then the last one is set. By default is **Int.max**.
     *      - validCharacterSet: Set of characters a client can input. By default is **nil** meaning any character.
     *      - predicate: Predicate to check whether normalized value is valid. By default **nil**
     *      meaning any value is valid.
     *      - preprocessor: Prepocessor is responsible to process the value before replacement of current value.
     *      By default is **nil** meaning no preprocessing.
     *      - normalizer: Preprocessor to process the value before checking its validity. Also normalized value
     *      is available via corresponding property. It can be used, for example, to trim current value.
     *      By default is **nil** meaning no normalization.
     */

    public init(value: String = "",
                required: Bool = true,
                enabled: Bool = true,
                minLength: Int = 0,
                maxLength: Int = Int.max,
                validCharacterSet: CharacterSet? = nil,
                predicate: NSPredicate? = nil,
                processor: TextProcessing? = nil,
                normalizer: TextProcessing? = nil) {
        self.value = value
        self.required = required
        self.enabled = enabled

        let minLength = min(minLength, maxLength)

        if value.count < minLength {
            self.minLength = value.count
        } else {
            self.minLength = minLength
        }

        let maxLength = max(self.minLength, maxLength)

        if value.count > maxLength {
            self.maxLength = value.count
        } else {
            self.maxLength = maxLength
        }

        self.invalidCharacterSet = validCharacterSet?.inverted
        self.predicate = predicate
        self.processor = processor
        self.normalizer = normalizer
    }

    public var completed: Bool {
        if let predicate = predicate {
            return predicate.evaluate(with: normalizedValue)
        } else {
            return true
        }
    }

    public func clearValue() {
        value = ""
    }

    public func changeValue(to newValue: String) {
        value = newValue
    }

    public func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool {
        guard enabled else {
            return false
        }

        let newValue = (value as NSString).replacingCharacters(in: range, with: string)

        guard newValue.count >= minLength, newValue.count <= maxLength else {
            return false
        }

        if let currentInvalidSet = invalidCharacterSet,
            string.rangeOfCharacter(from: currentInvalidSet) != nil {
            return false
        }

        if let processor = processor {
            let processed = processor.process(text: newValue)

            value = processed

            return processed == newValue
        } else {
            value = newValue

            return true
        }
    }

    public func addObserver(_ observer: InputHandlingObserver) {
        guard !observers.contains(where: { $0.observer === observer }) else {
            return
        }

        observers.append(InputHandlingObserverWrapper(observer: observer))
        observers = observers.filter { $0.observer != nil }
    }

    public func removeObserver(_ observer: InputHandlingObserver) {
        observers = observers.filter { $0.observer !== observer && $0.observer != nil}
    }
}
