import Foundation

enum BocMagic: UInt32 {
    case V1 = 0x68ff65f3
    case V2 = 0xacc3a728
    case V3 = 0xb5ee9c72
}

/// BoC = Bag-of-Cells, data structure for efficient storage and transmission of a collection of cells.
struct Boc {
    let size: Int
    let offBytes: Int
    let cells: Int
    let rootsCount: UInt64
    let absent: UInt64
    let totalCellSize: Int
    let index: Data?
    let cellData: Data
    let rootIndices: [UInt64]
    
    init(data: Data) throws {
        let reader = Slice(data: data)
        guard let magic = BocMagic(rawValue: UInt32(try reader.loadUint(bits: 32))) else {
            throw TonError.custom("Invalid magic")
        }
        switch magic {
            case .V1, .V2:
                size = Int(try reader.loadUint(bits: 8))
                offBytes = Int(try reader.loadUint(bits: 8))
                cells = Int(try reader.loadUint(bits: size * 8))
                rootsCount = try reader.loadUint(bits: size * 8) // Must be 1
                absent = try reader.loadUint(bits: size * 8)
                totalCellSize = Int(try reader.loadUint(bits: offBytes * 8))
                index = try reader.loadBytes(cells * offBytes)
                cellData = try reader.loadBytes(totalCellSize)
                rootIndices = [0]
            
                if magic == BocMagic.V2 {
                    let crc32 = try reader.loadBytes(4)
                    if data.subdata(in: 0..<data.count-4).crc32c() != crc32 {
                        throw TonError.custom("Invalid CRC32C")
                    }
                }
            case .V3:
                let hasIdx = try reader.loadBoolean()
                let hasCrc32c = try reader.loadBoolean()
                let _/*hasCacheBits*/ = try reader.loadBoolean()
                let _/*flags*/ = try reader.loadUint(bits: 2) // Must be 0
                size = Int(try reader.loadUint(bits: 3))
                offBytes = Int(try reader.loadUint(bits: 8))
                cells = Int(try reader.loadUint(bits: size * 8))
                rootsCount = try reader.loadUint(bits: size * 8)
                absent = try reader.loadUint(bits: size * 8)
                totalCellSize = Int(try reader.loadUint(bits: offBytes * 8))
                var rootIndices: [UInt64] = []
                
                for _ in 0..<rootsCount {
                    rootIndices.append(try reader.loadUint(bits: size * 8))
                }
                
                self.rootIndices = rootIndices
                
                if hasIdx {
                    index = try reader.loadBytes(cells * offBytes)
                } else {
                    index = nil
                }
                
                cellData = try reader.loadBytes(totalCellSize)
                if hasCrc32c {
                    let crc32 = try reader.loadBytes(4)
                    
                    if data.subdata(in: 0..<(data.count - 4)).crc32c() != crc32 {
                        throw TonError.custom("Invalid CRC32C")
                    }
                }
        }
    }
}

func getRefsDescriptor(refs: [Cell], level: UInt32, type: CellType) -> UInt8 {
    let typeFactor: UInt8 = type != .ordinary ? 1 : 0
    return UInt8(refs.count) + typeFactor * 8 + UInt8(level) * 32
}

func getBitsDescriptor(bits: Bitstring) -> UInt8 {
    let len = bits.length
    return UInt8(ceil(Double(len) / 8) + floor(Double(len) / 8))
}

func readCell(reader: Slice, sizeBytes: Int) throws -> (exotic: Bool, bits: Bitstring, refs: [UInt64]) {
    let d1 = try reader.loadUint(bits: 8)
    let refsCount = d1 % 8
    let exotic = d1 & 8 != 0
    
    let d2 = try reader.loadUint(bits: 8)
    let dataBytesize = Int(ceil(Double(d2) / 2.0))
    let paddingAdded = d2 % 2 != 0
    
    var bits = Bitstring.empty
    if dataBytesize > 0 {
        if paddingAdded {
            bits = try reader.loadPaddedBits(bits: dataBytesize * 8)
        } else {
            bits = try reader.loadBits(dataBytesize * 8)
        }
    }
    
    var refs: [UInt64] = []
    for _ in 0..<refsCount {
        refs.append(try reader.loadUint(bits: sizeBytes * 8))
    }
    
    return (exotic: exotic, bits: bits, refs: refs)
}

func calcCellSize(cell: Cell, sizeBytes: Int) -> Int {
    return 2 /* D1+D2 */ + Int(ceil(Double(cell.bits.length) / 8.0)) + cell.refs.count * sizeBytes
}

func deserializeBoc(src: Data) throws -> [Cell] {
    let boc = try Boc(data: src)
    let reader = Slice(data: boc.cellData)
    
    var cells: [(bits: Bitstring, refs: [UInt64], exotic: Bool, result: Cell?)] = []
    for _ in 0..<boc.cells {
        let cell = try readCell(reader: reader, sizeBytes: boc.size)
        cells.append((cell.bits, cell.refs, cell.exotic, nil))
    }
    
    for i in stride(from: cells.count - 1, through: 0, by: -1) {
        if cells[i].result != nil {
            throw TonError.custom("Impossible")
        }
        
        var refs: [Cell] = []
        for r in cells[i].refs {
            guard r < UInt64(cells.count), Int(r) > i else {
                throw TonError.custom("Invalid BOC reference index")
            }
            if let result = cells[Int(r)].result {
                refs.append(result)
            } else {
                throw TonError.custom("Invalid BOC file")
            }
        }
        
        cells[i].result = try Cell(exotic: cells[i].exotic, bits: cells[i].bits, refs: refs)
    }

    var roots: [Cell] = []
    for i in 0..<boc.rootIndices.count {
        guard boc.rootIndices[i] < UInt64(cells.count),
              let root = cells[Int(boc.rootIndices[i])].result else {
            throw TonError.custom("Invalid BOC root index")
        }
        roots.append(root)
    }

    return roots
}

func writeCellToBuilder(cell: Cell, refs: [UInt64], sizeBytes: Int, to: Builder) throws -> Builder {
    let d1 = getRefsDescriptor(refs: cell.refs, level: cell.levelMask, type: cell.type)
    let d2 = getBitsDescriptor(bits: cell.bits)
    
    try to.store(uint: d1, bits: 8)
    try to.store(uint: d2, bits: 8)
    try to.store(data: cell.bits.bitsToPaddedBuffer())
    
    for r in refs {
        try to.store(uint: r, bits: sizeBytes * 8)
    }
    
    return to
}

func serializeBoc(root: Cell, idx: Bool, crc32: Bool) throws -> Data {
    let allCells = try topologicalSort(src: root)
    
    let cellsNum = allCells.count
    let hasIdx = idx
    let hasCrc32c = crc32
    let hasCacheBits = false
    let flags: UInt32 = 0
    let sizeBytes = max(Int(ceil(Double(try cellsNum.bitsCount(mode: .uint)) / 8.0)), 1)
    var totalCellSize: Int = 0
    var index: [Int] = []
    
    for c in allCells {
        let sz = calcCellSize(cell: c.cell, sizeBytes: sizeBytes)
        index.append(totalCellSize)
        totalCellSize += sz
    }
    
    let offsetBytes = max(Int(ceil(Double(try totalCellSize.bitsCount(mode: .uint)) / 8.0)), 1)
    let hasIdxFactor = hasIdx ? (cellsNum * offsetBytes) : 0
    let totalSize = (
        4 + // magic
        1 + // flags and s_bytes
        1 + // offset_bytes
        3 * sizeBytes + // cells_num, roots, complete
        offsetBytes + // full_size
        1 * sizeBytes + // root_idx
        hasIdxFactor +
        totalCellSize +
        (hasCrc32c ? 4 : 0)
    ) * 8

    // Serialize
    var builder = Builder(capacity: totalSize)
    try builder.store(uint: 0xb5ee9c72, bits: 32) // Magic
    try builder.store(bit: hasIdx) // Has index
    try builder.store(bit: hasCrc32c) // Has crc32c
    try builder.store(bit: hasCacheBits) // Has cache bits
    try builder.store(uint: flags, bits: 2) // Flags
    try builder.store(uint: sizeBytes, bits: 3) // Size bytes
    try builder.store(uint: offsetBytes, bits: 8) // Offset bytes
    try builder.store(uint: cellsNum, bits: sizeBytes * 8) // Cells num
    try builder.store(uint: 1, bits: sizeBytes * 8) // Roots num
    try builder.store(uint: 0, bits: sizeBytes * 8) // Absent num
    try builder.store(uint: totalCellSize, bits: offsetBytes * 8) // Total cell size
    try builder.store(uint: 0, bits: sizeBytes * 8) // Root id == 0

    if hasIdx {
        for i in 0 ..< cellsNum {
            try builder.store(uint: index[i], bits: offsetBytes * 8)
        }
    }

    for i in 0 ..< cellsNum {
        builder = try writeCellToBuilder(
            cell: allCells[i].cell,
            refs: allCells[i].refs,
            sizeBytes: sizeBytes,
            to: builder
        )
    }

    if hasCrc32c {
        let crc32 = (try builder.alignedBitstring()).crc32c()
        try builder.store(data: crc32)
    }

    let res = try builder.alignedBitstring()
    if res.count != totalSize / 8 {
        throw TonError.custom("Internal error")
    }
    
    return res
}

func topologicalSort(src: Cell) throws -> [(cell: Cell, refs: [UInt64])] {
    var pending: [Cell] = [src]
    var allCells = [String: (cell: Cell, refs: [String])]()
    var notPermCells = Set<String>()
    var sorted: [String] = []
    
    while pending.count > 0 {
        let cells = pending
        pending = []
        for cell in cells {
            let hash = cell.hash().hexString()
            if allCells.keys.contains(hash) {
                continue
            }
            
            notPermCells.insert(hash)
            allCells[hash] = (cell: cell, refs: cell.refs.map { $0.hash().hexString() })
            
            for r in cell.refs {
                pending.append(r)
            }
        }
    }
    
    var tempMark = Set<String>()
    func visit(hash: String) throws {
        if !notPermCells.contains(hash) {
            return
        }
        if tempMark.contains(hash) {
            throw TonError.custom("Not a DAG")
        }
        
        tempMark.insert(hash)
        for c in allCells[hash]!.refs {
            try visit(hash: c)
        }
        
        sorted.insert(hash, at: 0)
        tempMark.remove(hash)
        notPermCells.remove(hash)
    }
    
    while notPermCells.count > 0 {
        let id = Array(notPermCells)[0]
        try visit(hash: id)
    }
    
    var indexes = [String: UInt64]()
    for i in 0..<sorted.count {
        indexes[sorted[i]] = UInt64(i)
    }
    
    var result: [(cell: Cell, refs: [UInt64])] = []
    for ent in sorted {
        let rrr = allCells[ent]!
        result.append((cell: rrr.cell, refs: rrr.refs.map { indexes[$0]! }))
    }
    
    return result
}
