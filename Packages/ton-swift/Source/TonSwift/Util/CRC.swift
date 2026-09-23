import Foundation

extension Data {
    func crc16() -> Data {
        let poly: UInt32 = 0x1021
        var reg: UInt32 = 0
        var message = self
        message.append(0)
        message.append(0)
        
        for byte in message {
            var mask: UInt8 = 0x80
            while mask > 0 {
                reg <<= 1
                if byte & mask != 0 {
                    reg += 1
                }
                
                mask >>= 1
                if reg > 0xffff {
                    reg &= 0xffff
                    reg ^= poly
                }
            }
        }
        
        let highByte = UInt8(reg / 256)
        let lowByte = UInt8(reg % 256)
        
        return Data([highByte, lowByte])
    }
    
    func crc32c() -> Data {
        let poly: UInt32 = 0x82f63b78
        var crc: UInt32 = 0 ^ 0xffffffff
        
        for i in 0..<self.count {
            crc ^= UInt32(self[i])
            crc = ((crc & 1) != 0) ? (crc >> 1) ^ poly : crc >> 1
            crc = ((crc & 1) != 0) ? (crc >> 1) ^ poly : crc >> 1
            crc = ((crc & 1) != 0) ? (crc >> 1) ^ poly : crc >> 1
            crc = ((crc & 1) != 0) ? (crc >> 1) ^ poly : crc >> 1
            crc = ((crc & 1) != 0) ? (crc >> 1) ^ poly : crc >> 1
            crc = ((crc & 1) != 0) ? (crc >> 1) ^ poly : crc >> 1
            crc = ((crc & 1) != 0) ? (crc >> 1) ^ poly : crc >> 1
            crc = ((crc & 1) != 0) ? (crc >> 1) ^ poly : crc >> 1
        }
        crc = crc ^ 0xffffffff

        var res = Data(count: 4)
        res.withUnsafeMutableBytes { (resPointer: UnsafeMutableRawBufferPointer) -> Void in
            resPointer.storeBytes(of: crc.littleEndian, as: UInt32.self)
        }
        
        return res
    }
}
