//
//  ASN1Tests.swift
//  ASN1Tests
//
//  Created by Håvard Fossli on 29.08.2018.
//  Copyright © 2018 Håvard Fossli. All rights reserved.
//
import XCTest
@testable import ASN1

extension Data {
    init?(hex: String) {
        let length = hex.count / 2
        var data = Data(capacity: length)
        for i in 0 ..< length {
            let j = hex.index(hex.startIndex, offsetBy: i * 2)
            let k = hex.index(j, offsetBy: 2)
            let bytes = hex[j..<k]
            if var byte = UInt8(bytes, radix: 16) {
                data.append(&byte, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }
    var hex: String {
        return reduce("") {$0 + String(format: "%02x", $1)}
    }
}

extension Data {
    init(_ values: UInt8...) {
        self.init(values)
    }
}

extension Data {
    var binaryString: String {
        let strings: [String] = self.map {
            $0.binaryString
        }
        return strings.joined(separator: "_")
    }
}

extension FixedWidthInteger {
    var binaryString: String {
        return String(self, radix: 2)
    }
}

class ASN1Tests: XCTestCase {

    func testExample() {
        let hex = "308194024803b81c13553d3b43cf40c8b6ea83a17d0308cce774b9c4a419537fc68486c6c4ad16cef2e5fa6ac34b21f17d8e91d2984ea4e1d7f196e3ff84532a84dec4fa12a19b72cc66cdb218024802cf964aee0bb4497a0b91c6a752ba46f1a7737a737d6557312b882293e2cfe640ef7575d39a718508cb03a0237d8c31117c1dc5501ce37ed39ce3e3c0288669f0926bea1516b83d"

    }

    func testTLVBigPositiveInt() {
        let hex = "028181008fe2412a08e851a88cb3e853e7d54950b3278a2bcbeab54273ea0257cc6533ee882061a11756c12418e3a808d3bed931f3370b94b8cc43080b7024f79cb18d5dd66d82d0540984f89f970175059c89d4d5c91ec913d72a6b309119d6d442e0c49d7c9271e1b22f5c8deef0f1171ed25f315bb19cbc2055bf3a37424575dc9065"
        var data = Data(hex: hex)!
        do {
            let tlv = try ASN1.DER.Decoder.parse(&data)
            XCTAssertEqual(data.count, 0)
            switch tlv {
            case .integer(let int):
                XCTAssertEqual(int.count, 129)
                XCTAssertEqual(int.first, 0x00)
                XCTAssertEqual(int.last, 0x65)
            default:
                XCTFail("Expected int, but got \(tlv)")
            }
        } catch {
            XCTFail("Should not throw \(error)")
        }
    }

    func testTLVSmallPositiveInt() {
        let hex = "020103"
        var data = Data(hex: hex)!
        do {
            let tlv = try ASN1.DER.Decoder.parse(&data)
            XCTAssertEqual(data.count, 0, "expected to consume all bytes")
            let expected = ASN1.DER.TLV.integer(Data(hex: "03")!)
            XCTAssertEqual(expected, tlv)
        } catch {
            XCTFail("Should not throw \(error)")
        }
    }

    func testTLVObjectIdentifier() {
        let hex = "06092b0601040182371514"
        let data = Data(hex: hex)!
        do {
            var parsed = data
            let tlv = try ASN1.DER.Decoder.parse(&parsed)
            XCTAssertEqual(parsed.count, 0, "expected to consume all bytes")
            let decoded = ASN1.DER.TLV.objectIdentifier("1.3.6.1.4.1.311.21.20")
            XCTAssertEqual(decoded, tlv)
            let encoded = try ASN1.DER.Encoder.encode(decoded)
            XCTAssertEqual(encoded.hex, data.hex)
        } catch {
            XCTFail("Should not throw \(error)")
        }
    }

    func testTLVObjectIdentifier2() {
        let hex = "06072A86487F010105"
        let data = Data(hex: hex)!
        do {
            var parsed = data
            let tlv = try ASN1.DER.Decoder.parse(&parsed)
            XCTAssertEqual(parsed.count, 0, "expected to consume all bytes")
            let decoded = ASN1.DER.TLV.objectIdentifier("1.2.840.127.1.1.5")
            XCTAssertEqual(decoded, tlv)
            let encoded = try ASN1.DER.Encoder.encode(decoded)
            XCTAssertEqual(encoded.hex, data.hex)
        } catch {
            XCTFail("Should not throw \(error)")
        }
    }

    func testTLVObjectIdentifier3() {
        let hex = "06082A86488100010105"
        let data = Data(hex: hex)!
        do {
            var parsed = data
            let tlv = try ASN1.DER.Decoder.parse(&parsed)
            XCTAssertEqual(parsed.count, 0, "expected to consume all bytes")
            let decoded = ASN1.DER.TLV.objectIdentifier("1.2.840.128.1.1.5")
            XCTAssertEqual(decoded, tlv)
            let encoded = try ASN1.DER.Encoder.encode(decoded)
            XCTAssertEqual(encoded.hex, data.hex)
        } catch {
            XCTFail("Should not throw \(error)")
        }
    }

    func testTLVObjectIdentifier4() {
        let hex = "06092A864886F70D010105"
        let data = Data(hex: hex)!
        do {
            var parsed = data
            let tlv = try ASN1.DER.Decoder.parse(&parsed)
            XCTAssertEqual(parsed.count, 0, "expected to consume all bytes")
            let decoded = ASN1.DER.TLV.objectIdentifier("1.2.840.113549.1.1.5")
            XCTAssertEqual(decoded, tlv)
            let encoded = try ASN1.DER.Encoder.encode(decoded)
            XCTAssertEqual(encoded.hex, data.hex)
        } catch {
            XCTFail("Should not throw \(error)")
        }
    }

    func testTLVConsumesPartiallyWhenFaulty() {
        let hex = "06092b060104018237151403"
        var data = Data(hex: hex)!
        do {
            let tlv = try ASN1.DER.Decoder.parse(&data)
            XCTAssertEqual(data.count, 1)
            XCTAssertEqual(data.last, 0x03, "expected to have 0x03 as dangling byte as first tag identifier is 0x06")
            let expected = ASN1.DER.TLV.objectIdentifier("1.3.6.1.4.1.311.21.20")
            XCTAssertEqual(expected, tlv)
        } catch {
            XCTFail("Should not throw \(error)")
        }
    }

    func testTLVIntegerSequence() {
        let hex = "308194024803b81c13553d3b43cf40c8b6ea83a17d0308cce774b9c4a419537fc68486c6c4ad16cef2e5fa6ac34b21f17d8e91d2984ea4e1d7f196e3ff84532a84dec4fa12a19b72cc66cdb218024802cf964aee0bb4497a0b91c6a752ba46f1a7737a737d6557312b882293e2cfe640ef7575d39a718508cb03a0237d8c31117c1dc5501ce37ed39ce3e3c0288669f0926bea1516b83d"
        var data = Data(hex: hex)!
        do {
            let tlv = try ASN1.DER.Decoder.parse(&data)
            XCTAssertEqual(data.count, 0, "expected to consume all bytes")
            let firstInt = Data(hex: "03B81C13553D3B43CF40C8B6EA83A17D0308CCE774B9C4A419537FC68486C6C4AD16CEF2E5FA6AC34B21F17D8E91D2984EA4E1D7F196E3FF84532A84DEC4FA12A19B72CC66CDB218")!
            let secondInt = Data(hex: "02CF964AEE0BB4497A0B91C6A752BA46F1A7737A737D6557312B882293E2CFE640EF7575D39A718508CB03A0237D8C31117C1DC5501CE37ED39CE3E3C0288669F0926BEA1516B83D")!
            let expected = ASN1.DER.TLV.sequence([.integer(firstInt), .integer(secondInt)])
            XCTAssertEqual(expected, tlv)
        } catch {
            XCTFail("Should not throw \(error)")
        }
    }

    func testTLVSecp256r1() {
        let hex = Data(hex: "3059301306072A8648CE3D020106082A8648CE3D0301070342000474338D364C1A3FC3A1A854E68CBC55701CB23DAD7D89F6362150E29C57A2DD2BC206FF1F818F0053E166E6838392CB1E574B1DE19CBF6E249FE8032BD07A8773")!
        do {
            var data = hex
            let decoded = try ASN1.DER.Decoder.parse(&data)
            XCTAssertEqual(data.count, 0, "expected to consume all bytes")
            let expected = ASN1.DER.TLV
                .sequence([
                    .sequence([
                        .objectIdentifier("1.2.840.10045.2.1"),
                        .objectIdentifier("1.2.840.10045.3.1.7")
                        ]),
                    .unknown(Data(hex: "0342000474338D364C1A3FC3A1A854E68CBC55701CB23DAD7D89F6362150E29C57A2DD2BC206FF1F818F0053E166E6838392CB1E574B1DE19CBF6E249FE8032BD07A8773")!)
                    ])
            XCTAssertEqual(expected, decoded)
            let encoded = try ASN1.DER.Encoder.encode(decoded)
            XCTAssertEqual(hex, encoded)
        } catch {
            XCTFail("Should not throw \(error)")
        }

    }

    //    func testLengthForByte() {
    ////        XCTAssertEqual((try? ASN1.DER.TLV.length(Data(UInt8(0b0000_0000)))) ?? -1, 0)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_0001))) ?? -1, 1)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_0010))) ?? -1, 2)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_0011))) ?? -1, 3)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_0100))) ?? -1, 4)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_0101))) ?? -1, 5)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_0110))) ?? -1, 6)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_0111))) ?? -1, 7)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_1000))) ?? -1, 8)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_1001))) ?? -1, 9)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_1010))) ?? -1, 10)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_1011))) ?? -1, 11)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_1100))) ?? -1, 12)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_1101))) ?? -1, 13)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_1110))) ?? -1, 14)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0000_1111))) ?? -1, 15)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0001_0000))) ?? -1, 16)
    ////
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0001_1111))) ?? -1, 31)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0010_0000))) ?? -1, 32)
    ////
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0011_1111))) ?? -1, 63)
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0100_0000))) ?? -1, 64)
    ////
    ////        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b0111_1111))) ?? -1, 127)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0001), UInt8(0b1000_0000))) ?? -1, 128)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0001), UInt8(0b1111_1111))) ?? -1, 255)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0000_0001), UInt8(0b0000_0000))) ?? -1, 256)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0000_0001), UInt8(0b1111_1111))) ?? -1, 511)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0000_0010), UInt8(0b0000_0000))) ?? -1, 512)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0000_0010), UInt8(0b1111_1111))) ?? -1, 767)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0000_0011), UInt8(0b0000_0000))) ?? -1, 768)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0000_0011), UInt8(0b1111_1111))) ?? -1, 1023)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0000_0100), UInt8(0b0000_0000))) ?? -1, 1024)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0000_0111), UInt8(0b1111_1111))) ?? -1, 2047)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0000_1000), UInt8(0b0000_0000))) ?? -1, 2048)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0000_1011), UInt8(0b1111_1111))) ?? -1, 3071)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0000_1100), UInt8(0b0000_0000))) ?? -1, 3072)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0000_1111), UInt8(0b1111_1111))) ?? -1, 4_095)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0001_0000), UInt8(0b0000_0000))) ?? -1, 4_096)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0001_1111), UInt8(0b1111_1111))) ?? -1, 8_191)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0010_0000), UInt8(0b0000_0000))) ?? -1, 8_192)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0011_1111), UInt8(0b1111_1111))) ?? -1, 16_383)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0100_0000), UInt8(0b0000_0000))) ?? -1, 16_384)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b0111_1111), UInt8(0b1111_1111))) ?? -1, 32_767)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b1000_0000), UInt8(0b0000_0000))) ?? -1, 32_768)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0010), UInt8(0b1111_1111), UInt8(0b1111_1111))) ?? -1, 65_535)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b0000_0001), UInt8(0b0000_0000), UInt8(0b0000_0000))) ?? -1, 65_536)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b0000_0001), UInt8(0b1111_1111), UInt8(0b1111_1111))) ?? -1, 131_071)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b0000_0010), UInt8(0b0000_0000), UInt8(0b0000_0000))) ?? -1, 131_072)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b0000_0011), UInt8(0b1111_1111), UInt8(0b1111_1111))) ?? -1, 262_143)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b0000_0100), UInt8(0b0000_0000), UInt8(0b0000_0000))) ?? -1, 262_144)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b0000_0111), UInt8(0b1111_1111), UInt8(0b1111_1111))) ?? -1, 524_287)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b0000_1000), UInt8(0b0000_0000), UInt8(0b0000_0000))) ?? -1, 524_288)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b0000_1111), UInt8(0b1111_1111), UInt8(0b1111_1111))) ?? -1, 1_048_575)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b0001_0000), UInt8(0b0000_0000), UInt8(0b0000_0000))) ?? -1, 1_048_576)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b0001_1111), UInt8(0b1111_1111), UInt8(0b1111_1111))) ?? -1, 2_097_151)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b0010_0000), UInt8(0b0000_0000), UInt8(0b0000_0000))) ?? -1, 2_097_152)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b0011_1111), UInt8(0b1111_1111), UInt8(0b1111_1111))) ?? -1, 4_194_303)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b0100_0000), UInt8(0b0000_0000), UInt8(0b0000_0000))) ?? -1, 4_194_304)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b0111_1111), UInt8(0b1111_1111), UInt8(0b1111_1111))) ?? -1, 8_388_607)
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b1000_0000), UInt8(0b0000_0000), UInt8(0b0000_0000))) ?? -1, 8_388_608)
    //
    //        XCTAssertEqual(try? ASN1.DER.TLV.length(Data(UInt8(0b1000_0011), UInt8(0b1111_1111), UInt8(0b1111_1111), UInt8(0b1111_1111))) ?? -1, 16_777_215)
    //    }

    func testLength() {
        XCTAssertEqual(Data(UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: -999).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: -1).binaryString)

        XCTAssertEqual(Data(UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 0).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_0001)).binaryString, ASN1.DER.Encoder.LENGTH(count: 1).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_0010)).binaryString, ASN1.DER.Encoder.LENGTH(count: 2).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_0011)).binaryString, ASN1.DER.Encoder.LENGTH(count: 3).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_0100)).binaryString, ASN1.DER.Encoder.LENGTH(count: 4).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_0101)).binaryString, ASN1.DER.Encoder.LENGTH(count: 5).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_0110)).binaryString, ASN1.DER.Encoder.LENGTH(count: 6).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_0111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 7).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_1000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 8).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_1001)).binaryString, ASN1.DER.Encoder.LENGTH(count: 9).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_1010)).binaryString, ASN1.DER.Encoder.LENGTH(count: 10).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_1011)).binaryString, ASN1.DER.Encoder.LENGTH(count: 11).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_1100)).binaryString, ASN1.DER.Encoder.LENGTH(count: 12).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_1101)).binaryString, ASN1.DER.Encoder.LENGTH(count: 13).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_1110)).binaryString, ASN1.DER.Encoder.LENGTH(count: 14).binaryString)
        XCTAssertEqual(Data(UInt8(0b0000_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 15).binaryString)
        XCTAssertEqual(Data(UInt8(0b0001_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 16).binaryString)

        XCTAssertEqual(Data(UInt8(0b0001_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 31).binaryString)
        XCTAssertEqual(Data(UInt8(0b0010_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 32).binaryString)

        XCTAssertEqual(Data(UInt8(0b0011_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 63).binaryString)
        XCTAssertEqual(Data(UInt8(0b0100_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 64).binaryString)

        XCTAssertEqual(Data(UInt8(0b0111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 127).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0001), UInt8(0b1000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 128).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0001), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 255).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0000_0001), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 256).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0000_0001), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 511).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0000_0010), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 512).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0000_0010), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 767).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0000_0011), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 768).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0000_0011), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 1023).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0000_0100), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 1024).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0000_0111), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 2047).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0000_1000), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 2048).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0000_1011), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 3071).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0000_1100), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 3072).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0000_1111), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 4_095).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0001_0000), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 4_096).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0001_1111), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 8_191).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0010_0000), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 8_192).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0011_1111), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 16_383).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0100_0000), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 16_384).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b0111_1111), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 32_767).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b1000_0000), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 32_768).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0010), UInt8(0b1111_1111), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 65_535).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b0000_0001), UInt8(0b0000_0000), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 65_536).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b0000_0001), UInt8(0b1111_1111), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 131_071).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b0000_0010), UInt8(0b0000_0000), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 131_072).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b0000_0011), UInt8(0b1111_1111), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 262_143).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b0000_0100), UInt8(0b0000_0000), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 262_144).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b0000_0111), UInt8(0b1111_1111), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 524_287).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b0000_1000), UInt8(0b0000_0000), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 524_288).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b0000_1111), UInt8(0b1111_1111), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 1_048_575).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b0001_0000), UInt8(0b0000_0000), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 1_048_576).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b0001_1111), UInt8(0b1111_1111), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 2_097_151).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b0010_0000), UInt8(0b0000_0000), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 2_097_152).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b0011_1111), UInt8(0b1111_1111), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 4_194_303).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b0100_0000), UInt8(0b0000_0000), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 4_194_304).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b0111_1111), UInt8(0b1111_1111), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 8_388_607).binaryString)
        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b1000_0000), UInt8(0b0000_0000), UInt8(0b0000_0000)).binaryString, ASN1.DER.Encoder.LENGTH(count: 8_388_608).binaryString)

        XCTAssertEqual(Data(UInt8(0b1000_0011), UInt8(0b1111_1111), UInt8(0b1111_1111), UInt8(0b1111_1111)).binaryString, ASN1.DER.Encoder.LENGTH(count: 16_777_215).binaryString)
    }



}
