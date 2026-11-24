import Foundation
import Observation
import WalletCore

/// The grid of words for importing a recovery phrase: autocomplete from the
/// BIP-39 list, paste of a whole phrase into any field, and highlighting of
/// words that are not in the list.
@MainActor
@Observable
final class PhraseEntryModel {
    static let lengths = MnemonicLength.allCases.map(\.rawValue)

    @ObservationIgnored let wordList: [String]
    @ObservationIgnored private let wordSet: Set<String>
    @ObservationIgnored private let validate: @Sendable ([String]) async -> MnemonicValidation
    @ObservationIgnored private var generation = 0

    private(set) var wordCount: Int
    private(set) var words: [String]
    /// The engine's verdict on the complete phrase; nil while incomplete or checking.
    private(set) var validation: MnemonicValidation?
    private(set) var isValidating = false
    /// The field being edited, so its half-typed word is not flagged yet.
    var focusedIndex: Int?

    init(wordList: [String], wordCount: Int = 12, validate: @escaping @Sendable ([String]) async -> MnemonicValidation) {
        self.wordList = wordList
        wordSet = Set(wordList)
        self.validate = validate
        self.wordCount = wordCount
        words = Array(repeating: "", count: wordCount)
    }

    var filledCount: Int { words.filter { !$0.isEmpty }.count }
    var isComplete: Bool { filledCount == wordCount }
    var normalizedWords: [String] { words.map { $0.lowercased() } }

    func setWordCount(_ count: Int) {
        guard Self.lengths.contains(count), count != wordCount else { return }
        var resized = Array(words.prefix(count))
        if resized.count < count { resized += Array(repeating: "", count: count - resized.count) }
        wordCount = count
        words = resized
        changed()
    }

    func clear() {
        words = Array(repeating: "", count: wordCount)
        changed()
    }

    /// Text typed or pasted into field `index`. Several words at once are
    /// spread over the following fields; a whole phrase of another valid
    /// length resizes the grid.
    func setText(_ text: String, at index: Int) {
        guard words.indices.contains(index) else { return }
        let tokens = Self.tokens(in: text)
        if tokens.count <= 1 {
            let word = tokens.first ?? ""
            guard words[index] != word else { return }
            words[index] = word
            changed()
            return
        }
        var start = index
        if Self.lengths.contains(tokens.count), tokens.count != wordCount || index != 0 {
            // A complete phrase was pasted: it replaces the whole grid.
            if tokens.count != wordCount {
                wordCount = tokens.count
                words = Array(repeating: "", count: tokens.count)
            }
            start = 0
        }
        for (offset, token) in tokens.enumerated() where words.indices.contains(start + offset) {
            words[start + offset] = token
        }
        focusedIndex = min(start + tokens.count, wordCount - 1)
        changed()
    }

    /// The fields `setText(text, at: index)` overwrites or removes: one
    /// word replaces its own field, several words the fields they spread
    /// over, and a whole phrase the whole grid.
    func indicesReplaced(bySetting text: String, at index: Int) -> Range<Int> {
        let count = Self.tokens(in: text).count
        guard words.indices.contains(index) else { return index..<index }
        if count > 1, Self.lengths.contains(count), count != wordCount || index != 0 {
            return 0..<wordCount
        }
        return index..<min(index + max(count, 1), wordCount)
    }

    /// The fields `setWordCount(count)` removes.
    func indicesRemoved(bySettingWordCount count: Int) -> Range<Int> {
        count < wordCount ? count..<wordCount : wordCount..<wordCount
    }

    /// Lowercased words of a pasted or typed text; numbering, commas and
    /// other punctuation are dropped.
    static func tokens(in text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// Up to `limit` list words starting with what is typed in a field.
    func suggestions(at index: Int, limit: Int = 5) -> [String] {
        guard words.indices.contains(index) else { return [] }
        let prefix = words[index]
        guard !prefix.isEmpty, !wordSet.contains(prefix) || wordList.contains(where: { $0 != prefix && $0.hasPrefix(prefix) }) else { return [] }
        var result: [String] = []
        for word in wordList where word.hasPrefix(prefix) && word != prefix {
            result.append(word)
            if result.count == limit { break }
        }
        return result
    }

    func acceptSuggestion(_ word: String, at index: Int) {
        guard words.indices.contains(index) else { return }
        words[index] = word
        focusedIndex = index + 1 < wordCount ? index + 1 : nil
        changed()
    }

    /// True for a field whose word is not in the list. The field being
    /// edited is only flagged once no list word can start with its text.
    func isUnknown(_ index: Int) -> Bool {
        guard words.indices.contains(index) else { return false }
        let word = words[index]
        guard !word.isEmpty else { return false }
        if focusedIndex == index, !wordSet.contains(word), wordList.contains(where: { $0.hasPrefix(word) }) {
            return false
        }
        if case .unknownWords(let indices)? = validation, indices.contains(index) { return true }
        if wordSet.isEmpty || wordSet.contains(word) { return false }
        return true
    }

    var unknownIndices: [Int] {
        words.indices.filter { isUnknown($0) }
    }

    /// One sentence about what is wrong, or nil.
    var problem: String? {
        let unknown = unknownIndices
        if !unknown.isEmpty {
            let numbers = unknown.map { String($0 + 1) }.joined(separator: ", ")
            return unknown.count == 1
                ? "Word \(numbers) is not in the recovery word list."
                : "Words \(numbers) are not in the recovery word list."
        }
        switch validation {
        case .invalidChecksum?:
            return "These words do not form a valid phrase. Check their order and spelling."
        case .invalidLength(let count)?:
            return "A recovery phrase has 12, 15, 18, 21 or 24 words, not \(count)."
        default:
            return nil
        }
    }

    var isValid: Bool {
        isComplete && validation == .valid
    }

    private func changed() {
        generation += 1
        validation = nil
        guard isComplete else {
            isValidating = false
            return
        }
        let current = generation
        let candidate = normalizedWords
        isValidating = true
        Task {
            let verdict = await validate(candidate)
            guard current == generation else { return }
            validation = verdict
            isValidating = false
        }
    }

    /// Runs the engine's validation now and waits for the verdict.
    func revalidate() async {
        guard isComplete else {
            validation = nil
            return
        }
        generation += 1
        let current = generation
        isValidating = true
        let verdict = await validate(normalizedWords)
        guard current == generation else { return }
        validation = verdict
        isValidating = false
    }
}
