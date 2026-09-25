import XCTest
@testable import TonSwift

final class BitStringTest: XCTestCase {

    func testBitString() throws {
        // should read bits
        let bs = Bitstring(data: Data([0b10101010]), unchecked:(offset: 0, length: 8))
        XCTAssertEqual(try bs.at(0), 1)
        XCTAssertEqual(try bs.at(1), 0)
        XCTAssertEqual(try bs.at(2), 1)
        XCTAssertEqual(try bs.at(3), 0)
        XCTAssertEqual(try bs.at(4), 1)
        XCTAssertEqual(try bs.at(5), 0)
        XCTAssertEqual(try bs.at(6), 1)
        XCTAssertEqual(try bs.at(7), 0)
        XCTAssertEqual(bs.toString(), "AA")
        
        // should equals
        let a = Bitstring(data: Data([0b10101010]), unchecked:(offset: 0, length: 8))
        let b = Bitstring(data: Data([0b10101010]), unchecked:(offset: 0, length: 8))
        let c = Bitstring(data: Data([0, 0b10101010]), unchecked:(offset: 8, length: 8))
        XCTAssertEqual(a, b)
        XCTAssertEqual(b, a)
        XCTAssertEqual(a, c)
        XCTAssertEqual(c, a)
        XCTAssertEqual(a.toString(), "AA")
        XCTAssertEqual(b.toString(), "AA")
        XCTAssertEqual(c.toString(), "AA")
        
        // should format strings
        XCTAssertEqual(try Bitstring(data: Data([0b00000000]), offset: 0, length: 1).toString(), "4_")
        XCTAssertEqual(try Bitstring(data: Data([0b10000000]), offset: 0, length: 1).toString(), "C_")
        XCTAssertEqual(try Bitstring(data: Data([0b11000000]), offset: 0, length: 2).toString(), "E_")
        XCTAssertEqual(try Bitstring(data: Data([0b11100000]), offset: 0, length: 3).toString(), "F_")
        XCTAssertEqual(try Bitstring(data: Data([0b11100000]), offset: 0, length: 4).toString(), "E")
        XCTAssertEqual(try Bitstring(data: Data([0b11101000]), offset: 0, length: 5).toString(), "EC_")
        
        // should do subbuffers
        let bs1 = Bitstring(data: Data([1, 2, 3, 4, 5, 6, 7, 8]), unchecked:(offset: 0, length: 64))
        let bs2 = try bs1.subbuffer(offset: 0, length: 16)
        XCTAssertEqual(bs2!.count, 2)
        
        // should process monkey strings
        let cases = [
            ("001110101100111010", "3ACEA_"),
            ("01001", "4C_"),
            ("000000110101101010", "035AA_"),
            ("1000011111100010111110111", "87E2FBC_"),
            ("0111010001110010110", "7472D_"),
            ("", ""),
            ("0101", "5"),
            ("010110111010100011110101011110", "5BA8F57A_"),
            ("00110110001101", "3636_"),
            ("1110100", "E9_"),
            ("010111000110110", "5C6D_"),
            ("01", "6_"),
            ("1000010010100", "84A4_"),
            ("010000010", "414_"),
            ("110011111", "CFC_"),
            ("11000101001101101", "C536C_"),
            ("011100111", "73C_"),
            ("11110011", "F3"),
            ("011001111011111000", "67BE2_"),
            ("10101100000111011111", "AC1DF"),
            ("0100001000101110", "422E"),
            ("000110010011011101", "19376_"),
            ("10111001", "B9"),
            ("011011000101000001001001110000", "6C5049C2_"),
            ("0100011101", "476_"),
            ("01001101000001", "4D06_"),
            ("00010110101", "16B_"),
            ("01011011110", "5BD_"),
            ("1010101010111001011101", "AAB976_"),
            ("00011", "1C_"),
            ("11011111111001111100", "DFE7C"),
            ("1110100100110111001101011111000", "E93735F1_"),
            ("10011110010111100110100000", "9E5E682_"),
            ("00100111110001100111001110", "27C673A_"),
            ("01010111011100000000001110000", "57700384_"),
            ("010000001011111111111000", "40BFF8"),
            ("0011110001111000110101100001", "3C78D61"),
            ("101001011011000010", "A5B0A_"),
            ("1111", "F"),
            ("10101110", "AE"),
            ("1001", "9"),
            ("001010010", "294_"),
            ("110011", "CE_"),
            ("10000000010110", "805A_"),
            ("11000001101000100", "C1A24_"),
            ("1", "C_"),
            ("0100101010000010011101111", "4A8277C_"),
            ("10", "A_"),
            ("1010110110110110110100110010110", "ADB6D32D_"),
            ("010100000000001000111101011001", "50023D66_")
        ]
        
        for (bin, hex) in cases {
            let r = try Builder().store(binaryString: bin).bitstring()
            
            // Check that string is valid
            XCTAssertEqual(r.toBinary(), bin)
            
            // Check the hex string
            XCTAssertEqual(r.toString(), hex)
        }
    }
}
