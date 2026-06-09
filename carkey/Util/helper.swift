//
//  helper.swift
//  carkey
//
//  Created by Shilapi Chen on 9/28/25.
//
import Foundation
import SwiftUI
import MapKit

class GPSTool {
	
	static let BAIDU_LBS_TYPE = "bd09ll"
	static let pi = 3.1415926535897932384626;
	static let a = 6378245.0
	static let ee = 0.00669342162296594323
	static let x_pi = pi * 3000.0 / 180.0
	
	static func gps84_To_Gcj02(lon:Double, lat:Double) ->CLLocationCoordinate2D?{
		if GPSTool.outOfChina(lon: lon, lat: lat) {
			return nil
		}
		var dLat = GPSTool.transformLat(x: lon - 105.0, y: lat - 35.0)
		var dLon = GPSTool.transformLon(x: lon - 105.0, y: lat - 35.0)
		let radLat = (lat / 180.0) * pi
		var magic = sin(radLat)
		magic = 1 - ee * magic * magic
		let sqrtMagic = sqrt(magic)
		dLat = (dLat * 180.0) / (((a * (1 - ee)) / (magic * sqrtMagic)) * pi)
		dLon = (dLon * 180.0) / ((a / sqrtMagic) * cos(radLat) * pi)
		let mgLat = lat + dLat
		let mgLon = lon + dLon
		return  CLLocationCoordinate2D(latitude: mgLat, longitude: mgLon)
	}
	
	static func gcj02_To_Bd09(gg_lon:Double, gg_lat:Double)->CLLocationCoordinate2D {
		let x = gg_lon
		let y = gg_lat
		let z = sqrt(x * x + y * y) + 0.00002 * sin(y * x_pi);
		let theta = atan2(y, x) + 0.000003 * cos(x * x_pi);
		let bd_lon = z * cos(theta) + 0.0065;
		let bd_lat = z * sin(theta) + 0.006;
		return CLLocationCoordinate2D(latitude: bd_lat, longitude: bd_lon)
	}
	
	static func gps84_To_Bd09(lon:Double, lat:Double) ->CLLocationCoordinate2D?{
		if GPSTool.outOfChina(lon: lon, lat: lat) {
			return nil
		}
		if let gcl = GPSTool.gps84_To_Gcj02(lon: lon, lat: lat) {
			let bd = GPSTool.gcj02_To_Bd09(gg_lon: gcl.longitude, gg_lat: gcl.latitude)
			return bd
		}else{
			return nil
		}
	}
	
	static func gcj_To_Gps84(lon:Double, lat:Double) ->CLLocationCoordinate2D{
		let gps = GPSTool.transform(lon:lon, lat:lat)
		let longitude = lon * 2 - gps.longitude
		let latitude = lat * 2 - gps.latitude
		return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
	}
	
	static func bd09_To_Gcj02(bd_lon:Double, bd_lat:Double) ->CLLocationCoordinate2D{
		let x = bd_lon - 0.0065
		let y = bd_lat - 0.006
		let z = sqrt(x * x + y * y) - 0.00002 * sin(y * x_pi)
		let theta = atan2(y, x) - 0.000003 * cos(x * x_pi)
		let gg_lon = z * cos(theta)
		let gg_lat = z * sin(theta)
		return CLLocationCoordinate2D(latitude: gg_lat, longitude: gg_lon)
	}
	
	static func bd09_To_Gps84(bd_lon:Double, bd_lat:Double) ->CLLocationCoordinate2D{
		let gcj02 = GPSTool.bd09_To_Gcj02(bd_lon: bd_lon, bd_lat: bd_lat)
		let map84 = GPSTool.gcj_To_Gps84(lon: gcj02.longitude, lat: gcj02.latitude)
		return map84
	}
	
	static func transform(lon:Double, lat:Double) ->CLLocationCoordinate2D{
		if (GPSTool.outOfChina(lon: lon, lat: lat)) {
			return CLLocationCoordinate2D(latitude: lat, longitude: lon)
		}
		var dLat = GPSTool.transformLat(x: lon - 105.0, y: lat - 35.0)
		var dLon = GPSTool.transformLon(x: lon - 105.0, y: lat - 35.0);
		let radLat = (lat / 180.0) * pi
		var magic = sin(radLat)
		magic = 1 - ee * magic * magic
		let sqrtMagic = sqrt(magic)
		dLat = (dLat * 180.0) / (((a * (1 - ee)) / (magic * sqrtMagic)) * pi)
		dLon = (dLon * 180.0) / ((a / sqrtMagic) * cos(radLat) * pi)
		let mgLat = lat + dLat
		let mgLon = lon + dLon
		return CLLocationCoordinate2D(latitude: mgLat, longitude: mgLon)
	}
	
	static func outOfChina(lon:Double, lat:Double) ->Bool{
		if (lon < 72.004 || lon > 137.8347) {
			return true
		}
		if (lat < 0.8293 || lat > 55.8271) {
			return true
		}
		return false
	}
	
	static func transformLat(x:Double, y:Double) ->Double{
		var ret =
		-100.0 +
		2.0 * x +
		3.0 * y +
		0.2 * y * y +
		0.1 * x * y +
		0.2 * sqrt(abs(x))
		ret +=
		((20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0) /
		3.0
		ret +=
		((20.0 * sin(y * pi) + 40.0 * sin((y / 3.0) * pi)) * 2.0) / 3.0;
		ret +=
		((160.0 * sin((y / 12.0) * pi) + 320 * sin((y * pi) / 30.0)) *
		 2.0) /
		3.0
		return ret
	}
	
	static func transformLon(x:Double, y:Double) ->Double{
		var ret =
		300.0 +
		x +
		2.0 * y +
		0.1 * x * x +
		0.1 * x * y +
		0.1 * sqrt(abs(x))
		ret +=
		((20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0) /
		3.0
		ret +=
		((20.0 * sin(x * pi) + 40.0 * sin((x / 3.0) * pi)) * 2.0) / 3.0;
		ret +=
		((150.0 * sin((x / 12.0) * pi) + 300.0 * sin((x / 30.0) * pi)) *
		 2.0) /
		3.0
		return ret
	}
}

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
