import Foundation
import SwiftyBluetooth
import CoreBluetooth
import Combine
import SwiftUI
import CommonCrypto
import CryptoSwift
import OSLog

let loggerBle = Logger(
	subsystem: "logger.carkey.com",
	category: "ble"
)

// disconnected -> scanning  -> authorizing -> connected
enum BluetoothManagerState {
	case unknown
	case disconnected
	case authorizing
	case connected
	case scanning
	
	var description: String {
		switch self {
		case .unknown: return "Unknown"
		case .disconnected: return "Disconnected"
		case .authorizing: return "Authorizing"
		case .connected: return "Connected"
		case .scanning: return "Scanning"
		}
	}
}

extension Peripheral: @retroactive Identifiable {
	public var id: String {
		return self.identifier.uuidString
	}
}

struct BleTarget {
	var peripheral: Peripheral
	var authorizeRequestCharacteristic: CBCharacteristic?
	var authorizeResponseCharacteristic: CBCharacteristic?
	var controlRequestCharacteristic: CBCharacteristic?
	var controlResponseCharacteristic: CBCharacteristic?
}

class BluetoothManager: ObservableObject {
	static let shared = BluetoothManager()
	
	@Published var keyInfo: E300BleKeyInfoModel?
	@Published var avaliblePeripherals = [Peripheral]()
	@Published var target: BleTarget?
	@Published var state: BluetoothManagerState = .disconnected
	
	private var isFound = false
	
	private init(){
	}
}

extension BluetoothManager {
	func UpdateKey(key: E300BleKeyInfoModel) {
		self.keyInfo = key
		loggerBle.info("key info updated")
	}
	
	func getState() -> BluetoothManagerState {
		return self.state
	}
	
	func startScan() {
		loggerBle.info("scan start")
		self.state = .scanning
		self.isFound = false
		
		SwiftyBluetooth.scanForPeripherals(withServiceUUIDs: nil, timeoutAfter: 15) { scanResult in
			switch scanResult {
			case .scanStarted:
				self.state = .scanning
			case .scanResult(let peripheral, let advertisementData, _):
				self.onScanMatchCallback(peripheral: peripheral, advertisementData: advertisementData)
			case .scanStopped(let peripherals, let error):
				loggerBle.info("scan ended")
				if self.state == .scanning {
					self.state = .disconnected
				}
				self.avaliblePeripherals = peripherals
				if let error = error {
					loggerBle.error("Encountered error during scanning: \(error)")
				}
			}
		}
	}
	
	private func onScanMatchCallback(peripheral: Peripheral, advertisementData: [String: Any]) {
		guard !isFound,
			  let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
			  let targetMac = self.keyInfo?.bleMacStr else { return }
		
		let discoveredMac = getMacAddress(from: manufacturerData)
		
		if discoveredMac.uppercased() == targetMac.uppercased() {
			loggerBle.error("ble mac matched: \(discoveredMac)")
			self.isFound = true
			SwiftyBluetooth.stopScan()
			
			connectTo(peripheral: peripheral)
		}
	}
	
	private func connectTo(peripheral: Peripheral) {
		peripheral.connect(withTimeout: 5) { result in
			switch result {
			case .success:
				loggerBle.info("ble connected to \(peripheral.name ?? "unnamed")")
				self.target = BleTarget(peripheral: peripheral)
				
				NotificationCenter.default.addObserver(self,
													   selector: #selector(self.peripheralDidDisconnect(_:)),
													   name: Peripheral.PeripheralDisconnected,
													   object: peripheral)
				
				self.startServiceDiscovery(for: peripheral)
				
			case .failure(let error):
				loggerBle.error("failed to connect: \(error)")
				self.state = .disconnected
			}
		}
	}
	
	private func startServiceDiscovery(for peripheral: Peripheral) {
		loggerBle.info("starting discovery flow...")
		self.state = .authorizing
		
		peripheral.discoverServices(withUUIDs: nil) { [weak self] result in
			guard let self = self else { return }
			switch result {
			case .success(let services):
				for service in services {
					switch service.uuid {
					case SGMWBLEProfile.AuthorizeService.uuid:
						loggerBle.debug("discovered authorize service")
						self.discoverAuthorizationCharacteristics(for: peripheral, service: service)
					case SGMWBLEProfile.ControlService.uuid:
						loggerBle.debug("discovered control service")
						self.discoverControlCharacteristics(for: peripheral, service: service)
					default:
						loggerBle.debug("discovered unknown service: \(service.uuid); with description: \(service.description)")
					}
				}
			case .failure(let error):
				loggerBle.error("unable to find target services, disconnecting: \(error)")
				self.disconnectPeripheral(peripheral: peripheral)
			}
		}
	}
	
	private func discoverAuthorizationCharacteristics(for peripheral: Peripheral, service: CBService) {
		peripheral.discoverCharacteristics(withUUIDs: nil, ofServiceWithUUID: service.uuid) { [weak self] result in
			guard let self = self else { return }
			switch result {
			case .success(let characteristics):
				loggerBle.debug("discovered authorization characteristics")
				self.assignCharacteristics(characteristics)
			case .failure(let error):
				loggerBle.error("unable to find target characteristics under authorize service, disconnecting: \(error)")
				self.disconnectPeripheral(peripheral: peripheral)
			}
		}
	}
	
	private func discoverControlCharacteristics(for peripheral: Peripheral, service: CBService) {
		peripheral.discoverCharacteristics(withUUIDs: nil, ofServiceWithUUID: service.uuid) { [weak self] result in
			guard let self = self else { return }
			switch result {
			case .success(let characteristics):
				loggerBle.debug("discovered control characteristics")
				self.assignCharacteristics(characteristics)
			case .failure(let error):
				loggerBle.error("unable to find target characteristics under control service, disconnecting: \(error)")
				self.disconnectPeripheral(peripheral: peripheral)
			}
		}
	}
	
	private func assignCharacteristics(_ characteristics: [CBCharacteristic]) {
		for characteristic in characteristics {
			switch characteristic.uuid {
			case SGMWBLEProfile.AuthorizeService.Characteristics.Request.CBUUIDRepresentation:
				self.target?.authorizeRequestCharacteristic = characteristic
				loggerBle.debug("got authorizeRequestCharacteristic")
			case SGMWBLEProfile.AuthorizeService.Characteristics.Response.CBUUIDRepresentation:
				self.target?.authorizeResponseCharacteristic = characteristic
				loggerBle.debug("got authorizeResponseCharacteristic")
			case SGMWBLEProfile.ControlService.Characteristics.Request.CBUUIDRepresentation:
				self.target?.controlRequestCharacteristic = characteristic
				loggerBle.debug("got controlRequestCharacteristic")
			case SGMWBLEProfile.ControlService.Characteristics.Response.CBUUIDRepresentation:
				self.target?.controlResponseCharacteristic = characteristic
				loggerBle.debug("got controlResponseCharacteristic")
			default:
				loggerBle.debug("got unknown characteristic: \(characteristic.uuid); with description \(characteristic.description)")
			}
		}
		guard self.target?.authorizeResponseCharacteristic != nil,
			  self.target?.authorizeRequestCharacteristic != nil,
			  self.target?.controlRequestCharacteristic != nil,
			  self.target?.controlResponseCharacteristic != nil else { return }
		loggerBle.info("got all characterristics")
		self.setAllNotification()
	}
	
	private func setAllNotification() {
		guard let target = self.target,
			  let authResponseChar = target.authorizeResponseCharacteristic,
			  let controlResponseChar = target.controlResponseCharacteristic
		else { return }
		
		loggerBle.info("enabling notifications for authorization and control...")
		
		// Register observer BEFORE enabling notifications
		NotificationCenter.default.addObserver(
			forName: Peripheral.PeripheralCharacteristicValueUpdate,
			object: target.peripheral,
			queue: nil,
			using: characteristicValueUpdated(_:)
		)
		
		// Set notify value for auth
		target.peripheral.setNotifyValue(toEnabled: true, ofCharac: authResponseChar) { [weak self] result in
			guard let self = self else { return }
			switch result {
			case .success(let isNotifying) where isNotifying:
				target.peripheral.setNotifyValue(toEnabled: true, ofCharac: authResponseChar) { [weak self] result in
					guard let self = self else { return }
					switch result {
					case .success(let isNotifying) where isNotifying:
						loggerBle.debug("successfully set notify for authorize")
						// 这里调用鉴权逻辑
						self.sendInitialAuthorizationRequest()
					case .failure(let error):
						loggerBle.error("failed to set notify for authorize: \(error)")
						self.disconnectPeripheral(peripheral: target.peripheral)
					default:
						break
					}
				}
			case .failure(let error):
				loggerBle.error("failed to set notify for authorize: \(error)")
				self.disconnectPeripheral(peripheral: target.peripheral)
			default:
				break
			}
		}
		
		// Set notify value for control
		target.peripheral.setNotifyValue(toEnabled: true, ofCharac: controlResponseChar) { [weak self] result in
			guard let self = self else { return }
			switch result {
			case .success(let isNotifying) where isNotifying:
				target.peripheral.setNotifyValue(toEnabled: true, ofCharac: controlResponseChar) { [weak self] result in
					guard let self = self else { return }
					switch result {
					case .success(let isNotifying) where isNotifying:
						loggerBle.debug("successfully set notify for control")
					case .failure(let error):
						loggerBle.error("failed to set notify for control: \(error)")
						self.disconnectPeripheral(peripheral: target.peripheral)
					default:
						break
					}
				}
			case .failure(let error):
				loggerBle.error("failed to set notify for control: \(error)")
				self.disconnectPeripheral(peripheral: target.peripheral)
			default:
				break
			}
		}
	}
	
	// 通知回调
	private func characteristicValueUpdated(_ notification: Notification) {
		
		// check if notification can be unpack
		guard let characteristic = notification.userInfo?["characteristic"] as? CBCharacteristic,
			  let data = characteristic.value else {
			loggerBle.warning("received notification with no characteristic or value")
			return
		}
		
		loggerBle.debug("received notification for characteristic: \(characteristic.uuid.uuidString)")
		
		switch characteristic.uuid{
		case SGMWBLEProfile.AuthorizeService.Characteristics.Response.CBUUIDRepresentation:
			authorizeRequestCallback(data: data)
		default:
			loggerBle.debug("reecieved a notification from unknown characteristic \(characteristic.uuid.uuidString)")
		}
	}
	
	// 鉴权回调
	private func authorizeRequestCallback(data: Data) {
		guard var keyInfo = self.keyInfo else {
			loggerBle.error("no valid bt auth key")
			return
		}
		let responseData1 = UcuAuthorizationRequestFrame1(dataFrame: data, aesKey: keyInfo.authAesKey)
		let responseData2 = UcuAuthorizationRequestFrame2(dataFrame: data, aesKey: keyInfo.authAesKey)
		
		// check service id
		if responseData1.serviceId != "A857" {
			loggerBle.error("a notification with wrong service id \(responseData1.serviceId) is matched into auth")
		}
		
		switch responseData1.subfunction {
		case "0001":
			loggerBle.info("entered auth stage 1")
			keyInfo.randomData1 = responseData1.random1
			if keyInfo.keyIdHex == responseData1.blekey.UnPadZero() {
				self.keyInfo = keyInfo
				loggerBle.debug("auth stage 1 got random1: \(String(describing: keyInfo.randomData1))")
				self.sendSecondAuthorizationRequest()
			} else {
				loggerBle.error("auth stage 1 got wrong key id: \(String(describing: responseData1.blekey))")
			}
		case "0002":
			loggerBle.info("entered auth stage 2")
			if keyInfo.keyIdHex != responseData2.blekey.UnPadZero() {
				loggerBle.error("auth stage 2 got wrong key id: \(String(describing: responseData2.blekey))")
			}
			
			// check random2
			if keyInfo.randomData2 == responseData2.random2 {
				loggerBle.debug("auth stage 2 got correct random2 :\(String(describing: keyInfo.randomData2))")
				self.authOK()
			} else {
				loggerBle.error("auth stage 2 got wrong random2")
				self.disconnectPeripheral(peripheral: self.target!.peripheral)
			}
			
		default:
			loggerBle.warning("got unknown auth subfunction id")
		}
		
	}
	
	// step 1
	private func sendInitialAuthorizationRequest() {
		guard let keyInfo = self.keyInfo else {
			loggerBle.error("failed to send intial auth request, no key data")
			return
		}
		guard let target = self.target,
			  let requestChar = target.authorizeRequestCharacteristic else { return }
		
		if let payload = keyInfo.GenerateRequest1().ToDataFromHexString() {
			target.peripheral.writeValue(ofCharac: requestChar, value: payload, type: .withResponse) { result in
				if case .failure(let error) = result {
					self.disconnectPeripheral(peripheral: target.peripheral)
					loggerBle.error("failed to send initial authorization request: \(error.localizedDescription)")
				} else {
					loggerBle.info("successfully sent initial authorization request.")
				}
			}
		}
	}
	
	// step 2
	private func sendSecondAuthorizationRequest() {
		guard let keyInfo = self.keyInfo else {
			loggerBle.error("failed to send second auth request, no key data")
			return
		}
		guard let target = self.target,
			  let requestChar = target.authorizeRequestCharacteristic else { return }
		
		if let payload = keyInfo.GenerateRequest2().ToDataFromHexString() {
			target.peripheral.writeValue(ofCharac: requestChar, value: payload, type: .withResponse) { result in
				if case .failure(let error) = result {
					self.disconnectPeripheral(peripheral: target.peripheral)
					loggerBle.error("failed to send second authorization request: \(error.localizedDescription)")
				} else {
					loggerBle.info("successfully sent second authorization request.")
				}
			}
		}
	}
	
	private func authOK() {
		self.state = .connected
		loggerBle.info("\(String(describing: self.target!.peripheral.name)) connected and authorized!")
	}
	
	private func disconnectPeripheral(peripheral: Peripheral?) {
		guard let peripheralToDisconnect = peripheral else { return }
		peripheralToDisconnect.disconnect { _ in
			// Actual cleanup is handled by the notification observer
			loggerBle.info("disconnect command sent to \(peripheralToDisconnect.name ?? "unnamed")")
		}
	}
	
	@objc private func peripheralDidDisconnect(_ notification: Notification) {
		loggerBle.warning("target disconnected by notify")
		self.state = .disconnected
		self.target = nil
		
		if let peripheral = notification.object as? Peripheral {
			NotificationCenter.default.removeObserver(self, name: Peripheral.PeripheralDisconnected, object: peripheral)
			NotificationCenter.default.removeObserver(self, name: Peripheral.PeripheralCharacteristicValueUpdate, object: peripheral)
		}
	}
	
	private func getMacAddress(from manufacturerData: Data) -> String {
		guard manufacturerData.count >= 6 else { return "" }
		let macBytes = manufacturerData.suffix(6)
		return macBytes.ToHexEncodedString()
	}
}

// MARK: - App/UCU Data Frames (Unaltered)

// UCU -> App 的响授权响应帧1
struct UcuAuthorizationRequestFrame1 {
	let serviceId: String, subfunction: String, random1: String, blekey: String
	
	init(dataFrame: Data, aesKey: Data) {
		do {
			let decrypted: Array<UInt8> = try AES(
				key: Array(aesKey),
				blockMode: ECB(),
				padding: .noPadding
			).decrypt(Array(dataFrame))
			let decryptedString = decrypted.toHexString()
			
			// crc check
			if Data(decrypted).Crc16Checksum() != 0 {
				loggerBle.warning("crc check failed on 1st auth response")
			}
			// payload length check (maybe?)
			if Data(hex: String(decryptedString[32...33])).toHexString() != "01" {
				loggerBle.warning("payload length check failed on 1st auth response")
			}
			
			// 肢解
			let service = decryptedString[0...3]
			let subFunc = decryptedString[4...7]
			let random1 = decryptedString[16...23]
			let blekey = decryptedString[24...31]
			
			self.serviceId = String(service)
			self.subfunction = String(subFunc)
			self.random1 = String(random1)
			self.blekey = String(blekey)
			
		} catch {
			loggerBle.error("got unexpected error, probably decrypt error")
			self.serviceId = ""
			self.subfunction = ""
			self.random1 = ""
			self.blekey = ""
		}
	}
}

// UCU -> App 的响授权响应帧2
struct UcuAuthorizationRequestFrame2 {
	let serviceId: String, subfunction: String, random2: String, blekey: String
	
	init(dataFrame: Data, aesKey: Data) {
		do {
			let decrypted: Array<UInt8> = try AES(
				key: Array(aesKey),
				blockMode: ECB(),
				padding: .noPadding
			).decrypt(Array(dataFrame))
			let decryptedString = decrypted.toHexString()
			
			// crc check
			if Data(decrypted).Crc16Checksum() != 0 {
				loggerBle.warning("crc check failed on 1st auth response")
			}
			// payload length check (maybe?)
			if Data(hex: String(decryptedString[32...33])).toHexString() != "06" {
				loggerBle.warning("payload length check failed on 1st auth response")
			}
			
			// 肢解
			let service = decryptedString[0...3]
			let subFunc = decryptedString[4...7]
			let random2 = decryptedString[16...23]
			let blekey = decryptedString[24...31]
			
			self.serviceId = String(service)
			self.subfunction = String(subFunc)
			self.random2 = String(random2)
			self.blekey = String(blekey)
			
		} catch {
			loggerBle.error("got unexpected error, probably decrypt error")
			self.serviceId = ""
			self.subfunction = ""
			self.random2 = ""
			self.blekey = ""
		}
	}
}

// MARK: - Helper Extensions (Unaltered)

extension String {
	// 允许通过整数范围来获取 Substring
	// 例如：myString[0...4]
	subscript(_ range: CountableClosedRange<Int>) -> Substring {
		let start = self.index(self.startIndex, offsetBy: range.lowerBound)
		let end = self.index(start, offsetBy: range.count - 1)
		return self[start...end]
	}
	
	// 允许通过半开范围来获取 Substring
	// 例如：myString[0..<5]
	subscript(_ range: CountableRange<Int>) -> Substring {
		let start = self.index(self.startIndex, offsetBy: range.lowerBound)
		let end = self.index(self.startIndex, offsetBy: range.upperBound)
		return self[start..<end]
	}
	
	// 允许通过部分范围（从头开始）来获取
	// 例如：myString[..<5]
	subscript(_ range: PartialRangeUpTo<Int>) -> Substring {
		let end = self.index(self.startIndex, offsetBy: range.upperBound)
		return self[..<end]
	}
	
	// 允许通过部分范围（到结尾）来获取
	// 例如：myString[14...]
	subscript(_ range: PartialRangeFrom<Int>) -> Substring {
		let start = self.index(self.startIndex, offsetBy: range.lowerBound)
		return self[start...]
	}
}

extension Data {
	func ToHexEncodedString() -> String { return map { String(format: "%02hhX", $0) }.joined() }
	
	func xor(withData otherData: Data) -> Data {
		var xoredData = Data(capacity: Swift.min(self.count, otherData.count))
		let length = Swift.min(self.count, otherData.count)
		
		for i in 0..<length {
			xoredData.append(self[i] ^ otherData[i])
		}
		return xoredData
	}
	
	func Crc16Checksum() -> UInt16 {
		var crc: UInt16 = 0xFFFF, polynomial: UInt16 = 0xA001
		for byte in self {
			crc ^= UInt16(byte)
			for _ in 0..<8 { crc = (crc & 0x0001) != 0 ? (crc >> 1) ^ polynomial : crc >> 1 }
		}
		return crc
	}
	
	mutating func FromIntString(num: String) -> Data {
		guard let number = Int(num) else {
			logger.error("Failed to convert string to integer")
			return Data()
		}
		var bigEndianNumber = number.bigEndian
		self = Data(bytes: &bigEndianNumber, count: MemoryLayout.size(ofValue: bigEndianNumber))
		return self
	}
}

extension String {
	func ToDataFromHexString() -> Data? {
		var data = Data(capacity: self.count / 2)
		var index = self.startIndex
		while index < self.endIndex {
			let nextIndex = self.index(index, offsetBy: 2)
			if let b = UInt8(self[index..<nextIndex], radix: 16) { data.append(b) } else { return nil }
			index = nextIndex
		}
		return data
	}
	
	func PadZero(toLength length: Int) -> String {
		var padded = self; while padded.count < length { padded = "0" + padded }; return padded
	}
	
	func UnPadZero() -> String {
		var unpadded = self; while unpadded.hasPrefix("0") && unpadded.count > 1 { unpadded.removeFirst() }; return unpadded
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


// MARK: - Debug View (Unaltered)

#if DEBUG
struct BtDebugView: View {
	@StateObject var bt = BluetoothManager.shared
	
	var body: some View {
		NavigationView {
			List {
				Section(header: Text("Bluetooth")) {
					Text("Current State: \(bt.state.description)")
					Button("Start Scan", action: {
						bt.startScan()
					})
				}
				
				Section(header: Text("Discovered Peripherals")) {
					if bt.avaliblePeripherals.isEmpty {
						Text("None")
					} else {
						ForEach(bt.avaliblePeripherals) { peripheral in
							Text(peripheral.id)
						}
					}
				}
			}
			.navigationTitle("BT Debug")
		}
	}
}

#Preview {
	BtDebugView()
}
#endif
