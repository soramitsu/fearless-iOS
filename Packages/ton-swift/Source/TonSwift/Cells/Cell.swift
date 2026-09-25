import Foundation

/// Number of bits that fits into a cell
public let BitsPerCell = 1023

/// Number of refs that fits into a cell
public let RefsPerCell = 4


public enum CellType: Int {
    case ordinary = -1
    case prunedBranch = 1
    case libraryReference = 2
    case merkleProof = 3
    case merkleUpdate = 4
}

/// Metrics of a cell or a builder
public struct CellMetrics {
    /// Number of bits in the cell
    var bitsCount: Int
    /// Number of refs in the cell
    var refsCount: Int
}

/// TON cell
public struct Cell: Hashable {
    
    private let basic: BasicCell
    
    public var type: CellType { basic.type }
    public var bits: Bitstring { basic.bits }
    public var refs: [Cell] { basic.refs }

    public var level: UInt32 { mask.level }
    public var levelMask: UInt32 { mask.value }
    public var isExotic: Bool { type != .ordinary }
    
    public var metrics: CellMetrics {
        return CellMetrics(bitsCount: bits.length, refsCount: refs.count)
    }

    // Precomputed data
    private var _hashes: [Data] = []
    private var _depths: [UInt32] = []
    fileprivate let mask: LevelMask
    
    /// Empty cell with no bits and no refs.
    public static let empty = Cell()
    
    /// Initializes a new cell with. Exotic cells are parsed and resolved using their contents.
    public init(
        exotic: Bool = false,
        bits: Bitstring = Bitstring.empty,
        refs: [Cell] = []
    ) throws {
        
        if exotic {
            self.basic = try BasicCell.exotic(bits: bits, refs: refs)
        } else {
            if refs.count > RefsPerCell {
                throw TonError.custom("Invalid number of references")
            }
            if bits.length > BitsPerCell {
                throw TonError.custom("Bits overflow: \(bits.length) > \(BitsPerCell)")
            }
            
            self.basic = BasicCell(type: .ordinary, bits: bits, refs: refs)
        }
        let precomputed = try self.basic.precompute();
        self.mask = precomputed.mask
        self._depths = precomputed.depths
        self._hashes = precomputed.hashes
    }
    
    public init() {
        self.basic = BasicCell(type: .ordinary, bits: Bitstring.empty, refs: [])
        self.mask = LevelMask()
    }
    
    /// Initializes a new cell with plain bytestring. This does not parse Bag-of-Cells (BoC), but uses provided data as a bitstring (byte-aligned).
    /// Throws if data contains more than 1023 bits.
    public init(data: Data) throws {
        try self.init(bits: Bitstring(data: data))
    }
    
    /**
     Deserialize cells from BOC
    - parameter src: source buffer
    - returns array of cells
    */
    public static func fromBoc(src: Data) throws -> [Cell] {
        return try deserializeBoc(src: src)
    }

    /**
     Helper class that deserializes a single cell from BOC in base64
    - parameter src: source string
    */
    public static func fromBase64(src: String) throws -> Cell {
        guard let data = Data(base64Encoded: src) else {
            throw NSError()
        }

        let parsed = try Cell.fromBoc(src: data)
        if parsed.count != 1 {
            throw TonError.custom("Deserialized more than one cell")
        }

        return parsed[0]
    }
    
    /**
     Get cell hash
    - parameter level: level
    - returns cell hash
    */
    public func hash(level: Int = 3) -> Data {
        return _hashes[min(_hashes.count - 1, level)]
    }
    
    /// Returns the lowest-order hash that represents an actual tree of cells, possibly pruned.
    /// This is the hash of the data being transmitted.
    /// For the hash of the underlying contents see  `hash(level:)` method.
    public func representationHash() -> Data {
        return _hashes[0]
    }
    
    
    /**
     Get cell depth
    - parameter level: level
    - returns cell depth
    */
    public func depth(level: Int = 3) -> UInt32 {
        return _depths[min(_depths.count - 1, level)]
    }
    
    /// Convert cell to slice so it can be parsed.
    /// Same as `toSlice`.
    public func beginParse(allowExotic: Bool = false) throws -> Slice {
        if isExotic && !allowExotic {
            throw TonError.custom("Exotic cells cannot be parsed");
        }
        
        return Slice(cell: self)
    }
    
    /// Convert cell to slice so it can be parsed.
    /// Same as `beginParse`.
    public func toSlice() throws -> Slice {
        return try beginParse()
    }

    /// Convert cell to a builder that has this cell pre-stored. Finalizing this builder yields the same cell.
    public func toBuilder() throws -> Builder {
        return try Builder().store(slice: toSlice())
    }
    /**
     Serializes cell to BOC
    - parameter opts: options
    */
    public func toBoc(idx: Bool = false, crc32: Bool = true) throws -> Data {
        return try serializeBoc(root: self, idx: idx, crc32: crc32)
    }
    
    /**
     Format cell to string
    - parameter indent: indentation
    - returns string representation
    */
    public func toString(indent: String = "") throws -> String {
        var t = "x"
        if isExotic {
            switch type {
            case .merkleProof:
                t = "p"
            case .merkleUpdate:
                t = "u"
            case .prunedBranch:
                t = "p"
            default:
                break
            }
        }
        var s = indent + (isExotic ? t : "x") + "{" + (bits.toString()) + "}"
        for i in refs {
            s += "\n" + (try i.toString(indent: indent + " "))
        }
        
        return s
    }
    

}

// MARK: - Equatable
extension Cell: Equatable {
    /**
     Checks cell to be euqal to another cell
    - parameter other: other cell
    - returns true if cells are equal
    */
    public static func == (lhs: Cell, rhs: Cell) -> Bool {
        return lhs.hash() == rhs.hash()
    }
}

// MARK: - Internal implementation

/// Internal basic Cell data: type, bits and refs.
/// This is used for internal computations to produce full-featured `Cell` type with various precomputed data.
fileprivate struct BasicCell: Hashable {
    let type: CellType
    let bits: Bitstring
    let refs: [Cell]
    
    /// Parse the exotic cell
    static func exotic(bits: Bitstring, refs: [Cell]) throws -> Self {
        let reader = Slice(bits: bits)
        let typeInt = try reader.preloadUint(bits: 8)
        
        let type: CellType;
        switch typeInt {
        case 1:
            type = try resolvePruned(bits: bits, refs: refs).type
            
        case 2:
            guard bits.length == 264, refs.isEmpty else {
                throw TonError.custom("Library reference must contain exactly 264 bits and no references")
            }
            type = .libraryReference
            
        case 3:
            type = try resolveMerkleProof(bits: bits, refs: refs).type
            
        case 4:
            type = try resolveMerkleUpdate(bits: bits, refs: refs).type
            
        default:
            throw TonError.custom("Invalid exotic cell type: \(typeInt)")
        }
        
        return BasicCell(type: type, bits: bits, refs: refs)
    }

    // This function replicates precomputation logic on the cell data
    // https://github.com/ton-blockchain/ton/blob/24dc184a2ea67f9c47042b4104bbb4d82289fac1/crypto/vm/cells/DataCell.cpp#L214
    func precompute() throws -> (mask: LevelMask, hashes: [Data], depths: [UInt32]) {
        var levelMask: LevelMask
        var pruned: ExoticPruned? = nil
        
        switch type {
        case .ordinary:
            var mask: UInt32 = 0
            for r in refs {
                mask = mask | r.mask.value
            }
            levelMask = LevelMask(mask: mask)
            
        case .libraryReference:
            levelMask = LevelMask()

        case .prunedBranch:
            pruned = try exoticPruned(bits: bits, refs: refs)
            levelMask = LevelMask(mask: pruned!.mask)
            
        case .merkleProof:
            try exoticMerkleProof(bits: bits, refs: refs)
            levelMask = LevelMask(mask: refs[0].mask.value >> 1)
            
        case .merkleUpdate:
            try exoticMerkleUpdate(bits: bits, refs: refs)
            levelMask = LevelMask(mask: (refs[0].mask.value | refs[1].mask.value) >> 1)
        }
        
        //
        // Calculate hashes and depths
        // NOTE: https://github.com/ton-blockchain/ton/blob/24dc184a2ea67f9c47042b4104bbb4d82289fac1/crypto/vm/cells/DataCell.cpp#L214
        //
        
        var depths: [UInt32] = []
        var hashes: [Data] = []
        
        let hashCount = type == .prunedBranch ? 1 : levelMask.hashCount
        let totalHashCount = levelMask.hashCount
        let hashIOffset = totalHashCount - hashCount
        
        var hashI: UInt32 = 0
        for levelI in 0...levelMask.level {
            if !levelMask.isSignificant(level: levelI) {
                continue
            }
            
            if hashI < hashIOffset {
                hashI += 1
                continue
            }
            
            // Bits
            var currentBits: Bitstring
            if hashI == hashIOffset {
                if !(levelI == 0 || type == .prunedBranch) {
                    throw TonError.custom("Invalid")
                }
                currentBits = bits
            } else {
                if !(levelI != 0 && type != .prunedBranch) {
                    throw TonError.custom("Invalid: \(levelI), \(type)")
                }
                currentBits = Bitstring(data: hashes[Int(hashI - hashIOffset) - 1], unchecked: (offset: 0, length: 256))
            }
            
            // Depth
            var currentDepth: UInt32 = 0
            for c in refs {
                var childDepth: UInt32
                if type == .merkleProof || type == .merkleUpdate {
                    childDepth = c.depth(level: Int(levelI) + 1)
                } else {
                    childDepth = c.depth(level: Int(levelI))
                }
                currentDepth = max(currentDepth, childDepth)
            }
            if refs.count > 0 {
                currentDepth += 1
            }
            
            // Hash
            let repr = try getRepr(originalBits: bits, bits: currentBits, refs: refs, level: levelI, levelMask: levelMask.apply(level: levelI).value, type: type)
            let hash = repr.sha256()
            let destI = hashI - hashIOffset
            depths.insert(currentDepth, at: Int(destI))
            hashes.insert(hash, at: Int(destI))
            
            hashI += 1
        }
        
        // Calculate hash and depth for all levels
        var resolvedHashes: [Data] = []
        var resolvedDepths: [UInt32] = []
        if pruned != nil {
            for i in 0..<4 {
                let hashIndex = levelMask.apply(level: UInt32(i)).hashIndex
                let thisHashIndex = levelMask.hashIndex
                if hashIndex != thisHashIndex {
                    resolvedHashes.append(pruned!.pruned[Int(hashIndex)].hash)
                    resolvedDepths.append(pruned!.pruned[Int(hashIndex)].depth)
                } else {
                    resolvedHashes.append(hashes[0])
                    resolvedDepths.append(depths[0])
                }
            }
        } else {
            for i in 0..<4 {
                let hashIndex = levelMask.apply(level: UInt32(i)).hashIndex
                resolvedHashes.append(hashes[Int(hashIndex)])
                resolvedDepths.append(depths[Int(hashIndex)])
            }
        }
        
        return (levelMask, resolvedHashes, resolvedDepths)
    }
}

func getRepr(originalBits: Bitstring, bits: Bitstring, refs: [Cell], level: UInt32, levelMask: UInt32, type: CellType) throws -> Data {
    // Allocate
    let bitsLen = (bits.length + 7) / 8
    var repr = Data(count: 2 + bitsLen + (2 + 32) * refs.count)

    // Write descriptors
    var reprCursor = 0
    repr[reprCursor] = getRefsDescriptor(refs: refs, level: levelMask, type: type)
    reprCursor += 1
    repr[reprCursor] = getBitsDescriptor(bits: originalBits)
    reprCursor += 1

    // Write bits
    repr.replaceSubrange(reprCursor..<reprCursor + bitsLen, with: bits.bitsToPaddedBuffer())
    reprCursor += bitsLen

    // Write refs
    for c in refs {
        var childDepth: UInt32
        if type == .merkleProof || type == .merkleUpdate {
            childDepth = c.depth(level: Int(level) + 1)
        } else {
            childDepth = c.depth(level: Int(level))
        }
        repr[reprCursor] = UInt8(floor(Double(childDepth) / 256))
        reprCursor += 1
        repr[reprCursor] = UInt8(childDepth % 256)
        reprCursor += 1
    }
    for c in refs {
        var childHash: Data
        if type == .merkleProof || type == .merkleUpdate {
            childHash = c.hash(level: Int(level) + 1)
        } else {
            childHash = c.hash(level: Int(level))
        }
        
        for i in 0..<32 {
            repr[reprCursor + i] = childHash[i]
        }
        
        reprCursor += 32
    }

    return repr
}


public struct ExoticPruned {
    public var mask: UInt32
    public var pruned: [(depth: UInt32, hash: Data)]
}

func exoticPruned(bits: Bitstring, refs: [Cell]) throws -> ExoticPruned {
    let reader = Slice(bits: bits)

    let type = try reader.loadUint(bits: 8)
    if type != 1 {
        throw TonError.custom("Pruned branch cell must have type 1, got \(type)")
    }

    if refs.count != 0 {
        throw TonError.custom("Pruned Branch cell can't has refs, got \(refs.count)");
    }

    // Resolve cell
    var mask: LevelMask
    if bits.length == 280 {
        // Special case for config proof
        // This test proof is generated in the moment of voting for a slashing
        // it seems that tools generate it incorrectly and therefore doesn't have mask in it
        // so we need to hardcode it equal to 1
        mask = LevelMask(mask: 1)
    } else {
        let level = UInt32(try reader.loadUint(bits: 8))
        mask = LevelMask(mask: level)
        if mask.level < 1 || mask.level > 3 {
            throw TonError.custom("Pruned Branch cell level must be >= 1 and <= 3, got \(mask.level)/\(mask.value)");
        }

        // Read pruned
        let size = 8 + 8 + (mask.apply(level: mask.level - 1).hashCount * (256 /* Hash */ + 16 /* Depth */))
        if bits.length != size {
            throw TonError.custom("Pruned branch cell must have exactly size bits, got \(bits.length)");
        }
    }

    // Read pruned
    var pruned: [(depth: UInt32, hash: Data)] = []
    var hashes: [Data] = []
    var depths: [UInt32] = []
    for _ in 0..<mask.level { hashes.append(try reader.loadBytes(32)) }
    for _ in 0..<mask.level { depths.append(UInt32(try reader.loadUint(bits: 16))) }
    for index in 0..<hashes.count { pruned.append((depth: depths[index], hash: hashes[index])) }

    return ExoticPruned(mask: mask.value, pruned: pruned)
}

func resolvePruned(bits: Bitstring, refs: [Cell]) throws -> (type: CellType, depths: [UInt32], hashes: [Data], mask: LevelMask) {
    let pruned = try exoticPruned(bits: bits, refs: refs)
    var depths = [UInt32]()
    var hashes = [Data]()
    let mask = LevelMask(mask: pruned.mask)
    for i in 0..<pruned.pruned.count {
        depths.append(pruned.pruned[i].depth)
        hashes.append(pruned.pruned[i].hash)
    }
    
    return (CellType.prunedBranch, depths, hashes, mask)
}

func resolveMerkleProof(bits: Bitstring, refs: [Cell]) throws -> (type: CellType, depths: [UInt32], hashes: [Data], mask: LevelMask) {
    let _/*merkleProof*/ = try exoticMerkleProof(bits: bits, refs: refs)
    let depths = [UInt32]()
    let hashes = [Data]()
    let mask = LevelMask(mask: refs[0].level >> 1)
    
    return (CellType.merkleProof, depths, hashes, mask)
}

func resolveMerkleUpdate(bits: Bitstring, refs: [Cell]) throws -> (type: CellType, depths: [UInt32], hashes: [Data], mask: LevelMask) {
    let _/*merkleUpdate*/ = try exoticMerkleUpdate(bits: bits, refs: refs)
    let depths = [UInt32]()
    let hashes = [Data]()
    let mask = LevelMask(mask: (refs[0].level | refs[1].level) >> 1)
    
    return (CellType.merkleUpdate, depths, hashes, mask)
}

@discardableResult
func exoticMerkleUpdate(bits: Bitstring, refs: [Cell]) throws -> (proofDepth1: UInt32, proofDepth2: UInt32, proofHash1: Data, proofHash2: Data) {
    let reader = Slice(bits: bits)

    // type + hash + hash + depth + depth
    let size = 8 + (2 * (256 + 16))

    if bits.length != size {
        throw TonError.custom("Merkle Update cell must have exactly (8 + (2 * (256 + 16))) bits, got \(bits.length)")
    }

    if refs.count != 2 {
        throw TonError.custom("Merkle Update cell must have exactly 2 refs, got \(refs.count)")
    }

    let type = try reader.loadUint(bits: 8)
    if type != 4 {
        throw TonError.custom("Merkle Update cell type must be exactly 4, got \(type)")
    }

    let proofHash1 = try reader.loadBytes(32)
    let proofHash2 = try reader.loadBytes(32)
    let proofDepth1 = UInt32(try reader.loadUint(bits: 16))
    let proofDepth2 = UInt32(try reader.loadUint(bits: 16))

    if proofDepth1 != refs[0].depth(level: 0) {
        throw TonError.custom("Merkle Update cell ref depth must be exactly \(proofDepth1), got \(refs[0].depth(level: 0))")
    }

    if proofHash1 != refs[0].hash(level: 0) {
        throw TonError.custom("Merkle Update cell ref hash must be exactly \(proofHash1.hexString()), got \(refs[0].hash(level: 0).hexString())")
    }

    if proofDepth2 != refs[1].depth(level: 0) {
        throw TonError.custom("Merkle Update cell ref depth must be exactly \(proofDepth2), got \(refs[1].depth(level: 0))")
    }

    if proofHash2 != refs[1].hash(level: 0) {
        throw TonError.custom("Merkle Update cell ref hash must be exactly \(proofHash2.hexString()), got \(refs[1].hash(level: 0).hexString())")
    }

    return (proofDepth1, proofDepth2, proofHash1, proofHash2)
}

@discardableResult
func exoticMerkleProof(bits: Bitstring, refs: [Cell]) throws -> (proofDepth: UInt32, proofHash: Data) {
    let reader = Slice(bits: bits)

    // type + hash + depth
    let size = 8 + 256 + 16

    if bits.length != size {
        throw TonError.custom("Merkle Proof cell must have exactly (8 + 256 + 16) bits, got \(bits.length)")
    }
    if refs.count != 1 {
        throw TonError.custom("Merkle Proof cell must have exactly 1 ref, got \(refs.count)")
    }

    // Check type
    let type = try reader.loadUint(bits: 8)
    if type != 3 {
        throw TonError.custom("Merkle Proof cell must have type 3, got \(type)")
    }

    // Check data
    let proofHash = try reader.loadBytes(32)
    let proofDepth = UInt32(try reader.loadUint(bits: 16))
    let refHash = refs[0].hash(level: 0)
    let refDepth = refs[0].depth(level: 0)

    if proofDepth != refDepth {
        throw TonError.custom("Merkle Proof cell ref depth must be exactly \(proofDepth), got \(refDepth)")
    }

    if proofHash != refHash {
        throw TonError.custom("Merkle Proof cell ref hash must be exactly \(proofHash.hexString()), got \(refHash.hexString())")
    }

    return (proofDepth, proofHash)
}

public struct LevelMask {
    private var _mask: UInt32 = 0
    private var _hashIndex: UInt32
    private var _hashCount: UInt32
    
    public init(mask: UInt32 = 0) {
        self._mask = mask
        self._hashIndex = countSetBits(self._mask)
        self._hashCount = self._hashIndex + 1
    }
    
    public var value: UInt32 {
        return _mask
    }
    
    public var level: UInt32 {
        return UInt32(32 - _mask.leadingZeroBitCount)
    }
    
    public var hashIndex: UInt32 {
        return _hashIndex
    }
    
    public var hashCount: UInt32 {
        return _hashCount
    }
    
    public func apply(level: UInt32) -> LevelMask {
        return LevelMask(mask: _mask & ((1 << level) - 1))
    }
    
    public func isSignificant(level: UInt32) -> Bool {
        return level == 0 || (_mask >> (level - 1)) % 2 != 0
    }
}

extension LevelMask: Hashable {
    public static func == (lhs: LevelMask, rhs: LevelMask) -> Bool {
        return lhs._mask == rhs._mask &&
        lhs._hashIndex == rhs._hashIndex &&
        lhs._hashCount == rhs._hashCount
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_mask)
        hasher.combine(_hashIndex)
        hasher.combine(_hashCount)
    }
}

func countSetBits(_ n: UInt32) -> UInt32 {
    var n = n - ((n >> 1) & 0x55555555)
    n = (n & 0x33333333) + ((n >> 2) & 0x33333333)
    
    return (n + (n >> 4) & 0xF0F0F0F) * 0x1010101 >> 24
}

/// Returns minimum number of bits needed to encode values up to this one.
/// This is the same as TL-B notation `#<= n`. To quote the TVM paper:
///
/// Parametrized type `#<= p` with `p : #` (this notation means “p of type #”, i.e., a natural number)
/// denotes the subtype of the natural numbers type #, consisting of integers 0 . . . p;
/// it is serialized into ⌈log2(p + 1)⌉ bits as an unsigned big-endian integer.
public func bitsForInt(_ n: Int) -> Int {
    return Int(ceil(log2(Double(n + 1))))
}
