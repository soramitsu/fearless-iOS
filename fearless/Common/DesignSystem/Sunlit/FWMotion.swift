import UIKit

/// Events that may animate (spec section 4). Each one tells the user something happened.
enum FWMotionEvent: CaseIterable {
    case press
    case balanceChange
    case priceChange
    case syncRunning
    case syncFinished
    case syncFailed
    case listAppear
    case tabChange
    case txPending
    case txSuccess
    case txFailed
    case wrongPin
    case pinDigit
    case copied

    /// The specified duration of the full animation (one turn or breath for the two loops).
    var duration: TimeInterval {
        switch self {
        case .press: return FWSunlit.Motion.pressIn
        case .balanceChange: return FWSunlit.Motion.balanceRoll
        case .priceChange: return FWSunlit.Motion.priceFlash
        case .syncRunning: return FWSunlit.Motion.syncTurn
        case .syncFinished: return FWSunlit.Motion.syncBloom
        case .syncFailed: return FWSunlit.Motion.syncFailure
        case .listAppear: return FWSunlit.Motion.listRise
        case .tabChange: return FWSunlit.Motion.tabSlide
        case .txPending: return FWSunlit.Motion.pendingBreath
        case .txSuccess: return FWSunlit.Motion.txSuccess
        case .txFailed, .wrongPin: return FWSunlit.Motion.shake
        case .pinDigit: return FWSunlit.Motion.pinDotFill
        case .copied: return FWSunlit.Motion.copied
        }
    }

    /// Only these repeat, and only while the state they show lasts.
    var loops: Bool {
        self == .syncRunning || self == .txPending
    }
}

/// How an event animates under the current accessibility and effects settings.
enum FWMotionStyle: Equatable {
    /// The specified movement.
    case full(TimeInterval)
    /// No movement: an opacity or tint change of at most 150 ms that ends in the same final state.
    case crossfade(TimeInterval)
    /// Jump to the final state.
    case none

    var animates: Bool { self != .none }

    var duration: TimeInterval {
        switch self {
        case let .full(duration), let .crossfade(duration): return duration
        case .none: return 0
        }
    }
}

/// Reduced motion (iOS setting), Reduced effects (FW setting) and Calm surfaces replace movement with
/// short crossfades or nothing and keep the information. Calm surfaces (signing and recovery-phrase
/// screens) never animate beyond press feedback.
struct FWMotionPolicy: Equatable {
    var reduceMotion = false
    var reducedEffects = false
    var calm = false

    static let full = FWMotionPolicy()

    static func current(effects: FWEffects = .shared, calm: Bool = false) -> FWMotionPolicy {
        FWMotionPolicy(
            reduceMotion: effects.reduceMotion || UIAccessibility.isReduceMotionEnabled,
            reducedEffects: effects.tier == .reduced,
            calm: calm
        )
    }

    var isRestricted: Bool { reduceMotion || reducedEffects || calm }

    func style(for event: FWMotionEvent) -> FWMotionStyle {
        guard isRestricted else { return .full(event.duration) }
        if calm {
            return event == .press ? .crossfade(FWSunlit.Motion.pressIn) : .none
        }
        if event.loops || event == .listAppear {
            return .none
        }
        return .crossfade(min(event.duration, FWSunlit.Motion.maxCrossfade))
    }

    /// Press feedback scales only when movement is allowed; the shadow swap always shows.
    var pressScale: CGFloat {
        isRestricted ? 1 : FWSunlit.Motion.pressScale
    }
}

/// Plans the balance digit roll: which characters roll, which fade, and which way the value moved.
enum FWDigitRoll {
    enum Slot: Equatable {
        case stay(Character)
        case roll(from: Character, into: Character)
        /// A non-digit change, or a character with no counterpart: fades in.
        case fade(Character)
    }

    enum Direction: Equatable {
        case rising, falling, none
    }

    struct Plan: Equatable {
        /// One slot per character of the new text.
        let slots: [Slot]
        let direction: Direction
        /// Indices of the new text whose character changed; the part that gets the up/down tint.
        let changed: Range<Int>?

        var isEmpty: Bool { changed == nil }
    }

    /// Strings are right-aligned so fractional digits line up when the integer part grows or shrinks.
    static func plan(from old: String, to new: String) -> Plan {
        let oldCharacters = Array(old)
        let newCharacters = Array(new)
        let shift = newCharacters.count - oldCharacters.count
        var slots: [Slot] = []
        var first: Int?
        var last: Int?
        for (index, character) in newCharacters.enumerated() {
            let oldIndex = index - shift
            let previous = oldCharacters.indices.contains(oldIndex) ? oldCharacters[oldIndex] : nil
            if previous == character {
                slots.append(.stay(character))
                continue
            }
            first = first ?? index
            last = index
            if let previous = previous, previous.isWholeNumber, character.isWholeNumber {
                slots.append(.roll(from: previous, into: character))
            } else {
                slots.append(.fade(character))
            }
        }
        let changed = first.flatMap { start in last.map { start ..< $0 + 1 } }
        return Plan(slots: slots, direction: direction(from: oldCharacters, to: newCharacters), changed: changed)
    }

    /// A balance change keeps the text's currency affixes; a locale or currency switch changes them and is
    /// not shown as a change of value.
    static func isSameFormat(_ old: String, _ new: String) -> Bool {
        func affixes(_ text: String) -> (String, String) {
            let characters = Array(text)
            let prefix = characters.prefix { !$0.isWholeNumber }
            let suffix = characters.reversed().prefix { !$0.isWholeNumber }
            return (String(prefix), String(suffix.reversed()))
        }
        return affixes(old) == affixes(new)
    }

    /// Compares the numeric values the two texts show; currency symbols and grouping are ignored.
    static func direction(from old: [Character], to new: [Character]) -> Direction {
        guard let oldValue = numericValue(String(old)), let newValue = numericValue(String(new)) else {
            return .none
        }
        if newValue == oldValue { return .none }
        return newValue > oldValue ? .rising : .falling
    }

    /// The number a formatted amount shows. With both "." and "," the later one is the decimal mark;
    /// a mark that repeats, or appears once before exactly three digits, groups thousands.
    static func numericValue(_ text: String) -> Decimal? {
        let kept = Array(text.filter { $0.isWholeNumber || $0 == "." || $0 == "," })
        guard kept.contains(where: \.isWholeNumber) else { return nil }
        let marks = kept.filter { $0 == "." || $0 == "," }
        var decimalMark: Character?
        if Set(marks).count > 1 {
            decimalMark = marks.last
        } else if marks.count == 1, let mark = marks.first, let position = kept.firstIndex(of: mark) {
            let tail = kept[kept.index(after: position)...]
            decimalMark = tail.count == 3 ? nil : mark
        }
        var integer = ""
        var fraction = ""
        var inFraction = false
        for character in kept {
            if character == decimalMark {
                inFraction = true
            } else if character.isWholeNumber {
                if inFraction { fraction.append(character) } else { integer.append(character) }
            }
        }
        let literal = (integer.isEmpty ? "0" : integer) + (fraction.isEmpty ? "" : "." + fraction)
        return Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX"))
    }
}

/// Wallet sync state shown by the hero sun: an arc while chains connect, one bloom when they all are,
/// a dimmed sun with a warning dot when some cannot be reached.
enum FWSyncState: Equatable {
    case idle
    case syncing(progress: Double?)
    case synced
    case failed(unreachable: Int)
}

/// Folds connection events into `FWSyncState`. UI only: it reads events the chain registry already posts
/// and never opens, closes or retries a connection.
struct FWSyncTracker: Equatable {
    enum Connection: Equatable {
        case connecting, connected, unreachable
    }

    private(set) var connections: [String: Connection] = [:]
    private(set) var catalogSyncing = false
    private(set) var catalogFailed = false
    private(set) var balanceLoading = false
    /// Set once anything has synced in this session, so a later quiet moment reads as "synced".
    private(set) var hasSynced = false

    mutating func catalogSync(running: Bool) {
        catalogSyncing = running
        catalogFailed = false
        noteActivity()
    }

    mutating func catalogFailure() {
        catalogSyncing = false
        catalogFailed = true
    }

    mutating func balance(loading: Bool) {
        balanceLoading = loading
        noteActivity()
    }

    mutating func connection(_ chainId: String, _ connection: Connection) {
        connections[chainId] = connection
        noteActivity()
    }

    private mutating func noteActivity() {
        if isSyncing { hasSynced = true }
    }

    /// Connected chains out of those the registry is connecting or has connected.
    var progress: Double? {
        let tracked = connections.values.filter { $0 != .unreachable }
        guard !tracked.isEmpty else { return nil }
        return Double(tracked.filter { $0 == .connected }.count) / Double(tracked.count)
    }

    var unreachable: Int {
        connections.values.filter { $0 == .unreachable }.count
    }

    var isSyncing: Bool {
        catalogSyncing || balanceLoading || connections.values.contains(.connecting)
    }

    var state: FWSyncState {
        if catalogFailed { return .failed(unreachable: unreachable) }
        if isSyncing { return .syncing(progress: progress) }
        if unreachable > 0 { return .failed(unreachable: unreachable) }
        return hasSynced || !connections.isEmpty ? .synced : .idle
    }
}
