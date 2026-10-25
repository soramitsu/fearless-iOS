import Foundation
import BigInt

public class Builder {
    public let capacity: Int
    private var _buffer: Data
    private var _length: Int
    
    public private(set) var refs: [Cell]
    
    
    
    // MARK: - Initializers
    
        
    /// Initialize the Builder with a given capacity.
    /// Note: Builder can be used to construct larger bitstrings, not only 1023-bit Cells. E.g. to build a BoC.
    public init(capacity: Int = BitsPerCell) {
        self.capacity = capacity
        _buffer = Data(count: (capacity + 7) / 8)
        _length = 0
        self.refs = []
    }
    
    public convenience init(_ bits: Bitstring) throws {
        self.init()
        try self.store(bits: bits)
    }
    
    private init(capacity: Int, buffer: Data, length: Int, refs: [Cell]) {
        self.capacity = capacity
        self._buffer = buffer
        self._length = length
        self.refs = refs
    }
    
    
    // MARK: - Finalization
    
    
    /// Clones slice at its current state.
    public func clone() -> Builder {
        return Builder(capacity: capacity, buffer: _buffer, length: _length, refs: refs)
    }
    
    /// Completes cell
    public func endCell() throws -> Cell {
        let bits = Bitstring(data: _buffer, unchecked:(offset: 0, length: _length))
        return try Cell(bits: bits, refs: refs)
    }
    
    /// Same as `endCell`
    public func asCell() throws -> Cell {
        return try endCell()
    }

    /// Converts builder into BitString
    public func bitstring() -> Bitstring {
        return Bitstring(data: _buffer, unchecked:(offset: 0, length: _length))
    }
    
    /// Converts to data if the bitstring contains a whole number of bytes.
    /// If the bitstring is not byte-aligned, returns error.
    public func alignedBitstring() throws -> Data {
        if !aligned {
            throw TonError.custom("Builder buffer is not byte-aligned")
        }
        return _buffer.subdata(in: 0..._length / 8)
    }
    
    
    
    // MARK: - Metrics

    
    /// Returns whether the written bits are byte-aligned
    public var aligned: Bool {
        return _length % 8 == 0
    }
    
    /// Number of written bits
    public var bitsCount: Int {
        return _length
    }
    
    /// Number of references added to this cell
    public var refsCount: Int {
        return refs.count
    }
    
    /// Remaining bits available
    public var availableBits: Int {
        return capacity - bitsCount
    }
    
    /// Remaining refs available
    public var availableRefs: Int {
        return RefsPerCell - refsCount
    }
    
    /// Returns metrics for the currently stored data
    public var metrics: CellMetrics {
        return CellMetrics(bitsCount: bitsCount, refsCount: refsCount)
    }
    
    /// Returns metrics for the remaining space in the cell
    public var remainingMetrics: CellMetrics {
        return CellMetrics(bitsCount: availableBits, refsCount: availableRefs)
    }
    
    /// Tries to fit the cell with the given metrics and returns the remaining space.
    /// If the cell does not fit, returns `nil`.
    public func fit(_ cell: CellMetrics) -> CellMetrics? {
        if availableBits >= cell.bitsCount && availableRefs >= cell.refsCount {
            return CellMetrics(
                bitsCount: availableBits - cell.bitsCount,
                refsCount: availableRefs - cell.refsCount
            )
        } else {
            return nil
        }
    }
    
    
    // MARK: - Storing Generic Types
    
    
    /// Stores an object
    @discardableResult
    public func store(_ object: CellCodable) throws -> Self  {
        try object.storeTo(builder: self)
        return self
    }
    
    /// Stores an optional object with a single-bit prefix (`Maybe T`)
    @discardableResult
    public func storeMaybe(_ object: CellCodable?) throws -> Self {
        if let object = object {
            try store(bit: true)
            try store(object)
        } else {
            try store(bit: false)
        }
        
        return self
    }
    
    
    
    // MARK: - Storing Refs
    
    
    /**
     Store reference
     - parameter cell: cell or builder to store
     - returns this builder
     */
    @discardableResult
    public func store(ref cell: Cell) throws -> Self {
        if refs.count >= 4 {
            throw TonError.custom("Too many references")
        }
        refs.append(cell)
        return self
    }
    @discardableResult
    public func store(ref builder: Builder) throws -> Self {
        return try store(ref: try builder.endCell())
    }
    
    /**
     Store reference if not null
     - parameter cell: cell or builder to store
     - returns this builder
     */
    @discardableResult
    public func storeMaybe(ref cell: Cell?) throws -> Self {
        if let cell = cell {
            try store(bit: true)
            try store(ref: cell)
        } else {
            try store(bit: false)
        }
        
        return self
    }
    @discardableResult
    public func storeMaybe(ref builder: Builder?) throws -> Self {
        if let builder = builder {
            try store(bit: true)
            try store(ref: builder)
        } else {
            try store(bit: false)
        }
        
        return self
    }
    
    /**
     Store slice it in this builder
     - parameter src: source slice
     */
    @discardableResult
    public func store(slice: Slice) throws -> Self {
        let c = slice.clone()
        if c.remainingBits > 0 {
            try store(bits: c.loadBits(c.remainingBits))
        }
        while c.remainingRefs > 0 {
            try store(ref: c.loadRef())
        }
        
        return self
    }
    
    /**
     Store slice in this builder if not null
     - parameter src: source slice
     */
    public func storeMaybe(slice: Slice?) throws {
        if let slice = slice {
            try store(bit: true)
            try store(slice: slice)
        } else {
            try store(bit: false)
        }
    }
    
    
    
    // MARK: - Storing Dictionaries
    
    
    @discardableResult
    public func store(dict: any CellCodableDictionary) throws -> Self {
        try dict.storeTo(builder: self)
        return self
    }
    
    @discardableResult
    public func store(dictRoot dict: any CellCodableDictionary) throws -> Self {
        try dict.storeRootTo(builder: self)
        return self
    }
    
    
    
    
    // MARK: - Storing Bits
    

    /// Write a single bit: the bit is set for positive values, not set for zero or negative
    @discardableResult
    public func store(bit: Bit) throws -> Self {
        try checkCapacity(1)
        
        if bit > 0 {
            _buffer[_length / 8] |= 1 << (7 - (_length % 8))
        }
        
        _length += 1
        return self
    }
    
    /// Writes bit as a boolean (true => 1, false => 0)
    @discardableResult
    public func store(bit: Bool) throws -> Self {
        return try store(bit: bit ? 1 : 0)
    }
    
    /// Write repeating bit a given number of times.
    @discardableResult
    public func store(bit: Bit, repeat count: Int) throws -> Self {
        if count < 0 { throw TonError.custom("In store(bit:repeat:) repeat count must be non-negative.") }
        for _ in 0..<count {
            try store(bit: bit)
        }
        return self
    }
    
    /// Writes bits from a bitstring
    @discardableResult
    public func store(bits: Bitstring) throws -> Self {
        for i in 0..<bits.length {
            try store(bit: bits.at(i))
        }
        return self
    }

    /// Writes bits from a literal sequence of numbers
    @discardableResult
    public func store(bits: Bit...) throws -> Self {
        try checkCapacity(bits.count)
        for bit in bits {
            if bit > 0 {
                _buffer[_length / 8] |= 1 << (7 - (_length % 8))
            }
            _length += 1
        }
        return self
    }

    /// Writes bits from a textual string of binary digits
    @discardableResult
    public func store(binaryString: String) throws -> Self {
        for s in binaryString {
            if s != "0" && s != "1" {
                throw TonError.custom("Bitstring must contain only 0s and 1s. Invalid character: \(s)")
            }
            try store(bit: s == "1" ? 1 : 0)
        }
        return self
    }

    /// Writes bytes from the src data.
    @discardableResult
    public func store(data: Data) throws -> Self {
        try checkCapacity(data.count*8)
        
        // Special case for aligned offsets
        if aligned {
            for i in 0..<data.count {
                _buffer[_length / 8 + i] = data[i]
            }
            _length += data.count * 8
        } else {
            for i in 0..<data.count {
                try store(uint: data[i], bits: 8)
            }
        }
        return self
    }
    
    
    
    
    
    
    // MARK: - Storing Integers
    
    
    /**
     Write uint value
    - parameter value: value as bigint or number
    - parameter bits: number of bits to write
    */
    @discardableResult
    public func store<T>(uint value: T, bits: Int) throws -> Self where T: BinaryInteger {
        return try store(biguint: BigUInt(value), bits: bits)
    }
    
    @discardableResult
    public func store(biguint value: BigUInt, bits: Int) throws -> Self {
        try checkCapacity(bits)
        
        // Special cases when our buffer is aligned
        if aligned {
            // Special case for 8 bits
            if bits == 8 {
                let v = Int(value)
                if v < 0 || v > 255 {
                    throw TonError.custom("Value is out of range for \(bits) bits. Got \(value)")
                }
                
                _buffer[_length / 8] = UInt8(value)
                _length += 8
                
                return self
            }
            
            // Special case for 16 bits
            if bits == 16 {
                let v = Int(value)
                if v < 0 || v > 65536 {
                    throw TonError.custom("Value is out of range for \(bits) bits. Got \(value)")
                }
                _buffer[_length / 8] = UInt8(v >> 8)
                _buffer[_length / 8 + 1] = UInt8(v & 0xff)
                _length += 16
                
                return self
            }
        }
        
        // Corner case for zero bits
        if bits == 0 {
            if value != 0 {
                throw TonError.custom("value is not zero for \(bits) bits. Got \(value)")
            } else {
                return self
            }
        }
        
        // Generic case
        var v = value
        
        // Check input
        let vBits = (BigInt(1) << BigInt(bits))
        if v < 0 || v >= vBits {
            throw TonError.custom("BitLength is too small for a value \(value). Got \(bits)")
        }
        
        // Convert number to bits
        var b: [Bool] = []
        while v > 0 {
            b.append(v % 2 == 1)
            v /= 2
        }
        
        // Write bits
        for i in 0..<bits {
            let off = bits - i - 1
            if (off < b.count) {
                try store(bit: b[off])
            } else {
                try store(bit: false)
            }
        }
        return self
    }
    
    
    @discardableResult
    public func store(int value: any BinaryInteger, bits: Int) throws -> Self {
        return try store(bigint: BigInt(value), bits: bits)
    }
        
    @discardableResult
    func store(bigint value: BigInt, bits: Int) throws -> Self {
        var v = value
        if bits < 0 {
            throw TonError.custom("Invalid bit length. Got \(bits)")
        }
        
        if bits == 0 {
            if v != 0 {
                throw TonError.custom("Value is not zero for \(bits) bits. Got \(v)")
            } else {
                return self
            }
        }
        
        if bits == 1 {
            if v != -1 && v != 0 {
                throw TonError.custom("Value is not zero or -1 for \(bits) bits. Got \(v)")
            } else {
                try store(bit: v == -1)
                return self
            }
        }
        
        let vBits = 1 << (bits - 1)
        if v < -vBits || v >= vBits {
            throw TonError.custom("Value is out of range for \(bits) bits. Got \(v)")
        }
        
        if v < 0 {
            try store(bit: true)
            v = (1 << (bits - 1)) + v
        } else {
            try store(bit: false)
        }
        
        try store(uint: v, bits: bits - 1)
        return self
    }

    
    
    
    
    
    // MARK: - Storing Variable-Length Integers
    
    
    /// Stores VarUInteger with a given `limit` in bytes.
    /// The integer must be at most `limit-1` bytes long.
    /// Therefore, `(VarUInteger 16)` accepts 120-bit number (15 bytes) and uses 4 bits to encode length prefix 0...15.
    @discardableResult
    func store(varuint v: UInt64, limit: Int) throws -> Self {
        return try store(varuint: BigUInt(v), limit: limit)
    }
    
    /// Stores VarUInteger with a given `limit` in bytes.
    /// The integer must be at most `limit-1` bytes long.
    /// Therefore, `(VarUInteger 16)` accepts 120-bit number (15 bytes) and uses 4 bits to encode length prefix 0...15.
    @discardableResult
    func store(varuint v: BigUInt, limit: Int) throws -> Self {
        let maxsize = limit - 1
        if maxsize < 0 {
            throw TonError.custom("Invalid limit. Got \(limit) < 1")
        }
        if v.bitWidth > maxsize * 8 {
            throw TonError.varUIntOutOfBounds(limit: limit, actualBits: v.bitWidth)
        }
        
        let prefixSize = bitsForInt(maxsize)
        
        // Corner case for zero
        if v == 0 {
            // Write zero size
            try store(uint: 0, bits: prefixSize)
            return self
        }

        // Calculate size
        let sizeBytes = Int(ceil(Double(v.bitWidth) / 8.0))
        let sizeBits = sizeBytes * 8

        // Write size
        try store(uint: sizeBytes, bits: prefixSize)

        // Write number
        try store(uint: v, bits: sizeBits)
        
        return self
    }
    

    private func checkCapacity(_ bits: Int) throws {
        if availableBits < bits || bits < 0 {
            throw TonError.custom("Builder overflow: need to write \(bits), but available \(availableBits)")
        }
    }

}
