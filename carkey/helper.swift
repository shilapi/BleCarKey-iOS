//
//  helper.swift
//  carkey
//
//  Created by Shilapi Chen on 9/28/25.
//
import Foundation

extension String {
	// 允许通过整数范围来获取 Substring
	// 例如：myString[0...4]
	subscript(_ range: CountableClosedRange<Int>) -> String {
		let start = self.index(self.startIndex, offsetBy: range.lowerBound)
		let end = self.index(start, offsetBy: range.count - 1)
		return String(self[start...end])
	}
	
	// 允许通过半开范围来获取 Substring
	// 例如：myString[0..<5]
	subscript(_ range: CountableRange<Int>) -> String {
		let start = self.index(self.startIndex, offsetBy: range.lowerBound)
		let end = self.index(self.startIndex, offsetBy: range.upperBound)
		return String(self[start..<end])
	}
	
	// 允许通过部分范围（从头开始）来获取
	// 例如：myString[..<5]
	subscript(_ range: PartialRangeUpTo<Int>) -> String {
		let end = self.index(self.startIndex, offsetBy: range.upperBound)
		return String(self[..<end])
	}
	
	// 允许通过部分范围（到结尾）来获取
	// 例如：myString[14...]
	subscript(_ range: PartialRangeFrom<Int>) -> String {
		let start = self.index(self.startIndex, offsetBy: range.lowerBound)
		return String(self[start...])
	}
}

extension Data {
	func ToHexEncodedString() -> String {
		return map { String(format: "%02hhX", $0) }.joined()
	}
	
	func xor(withData otherData: Data) -> Data {
		var xoredData = Data(capacity: Swift.min(self.count, otherData.count))
		let length = Swift.min(self.count, otherData.count)
		
		for i in 0..<length {
			xoredData.append(self[i] ^ otherData[i])
		}
		return xoredData
	}
	
	func Crc16Checksum() -> Int {
		let buffer: [UInt8] = Array(self)
		var crc: Int = 0xFFFF
		
		for i in 0..<buffer.count {
			crc = (crc >> 8 ^ crc << 8) & 0xffff
			crc ^= Int((buffer[Int(i)] & 0xff))
			crc ^= (crc & 0xff) >> 4
			crc ^= (crc << 12) & 0xffff
			crc ^= ((crc & 0xff) << 5) & 0xffff
		}
		crc &= 0xffff
		return crc
	}
	
	mutating func FromIntString(num: String) -> Data {
		guard let number = Int(num) else {
			logger.error("Failed to convert string to integer")
			return Data()
		}
		var bigEndianNumber = number.bigEndian
		self = Data(
			bytes: &bigEndianNumber,
			count: MemoryLayout.size(ofValue: bigEndianNumber)
		)
		return self
	}
}

extension String {
	func ToDataFromHexString() -> Data? {
		var data = Data(capacity: self.count / 2)
		var index = self.startIndex
		while index < self.endIndex {
			let nextIndex = self.index(index, offsetBy: 2)
			if let b = UInt8(self[index..<nextIndex], radix: 16) {
				data.append(b)
			} else {
				return nil
			}
			index = nextIndex
		}
		return data
	}
	
	func PadZero(toLength length: Int) -> String {
		var padded = self
		while padded.count < length { padded = "0" + padded }
		return padded
	}
	
	func PadZeroOnTail(toLength length: Int) -> String {
		var padded = self
		while padded.count < length { padded = padded + "0" }
		return padded
	}
	
	func UnPadZero() -> String {
		var unpadded = self
		while unpadded.hasPrefix("0") && unpadded.count > 1 {
			unpadded.removeFirst()
		}
		return unpadded
	}
	
	func ToHexStringFromIntString() -> String {
		guard let number = Int(self) else {
			logger.error("Failed to convert string to integer")
			return String()
		}
		let hexString = String(number, radix: 16, uppercase: true)
		return hexString
	}
}
