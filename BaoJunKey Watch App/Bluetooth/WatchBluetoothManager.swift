//
//  WatchBluetoothManager.swift
//  BaoJunKey Watch App
//
//  CoreBluetooth-based BLE manager for watchOS
//  Mirrors the iOS BluetoothManager BLE protocol but uses
//  native CoreBluetooth delegates instead of SwiftyBluetooth
//

import CoreBluetooth
import Combine
import CryptoSwift
import Foundation
import OSLog
import SwiftUI

let loggerBleWatchManager = Logger(
    subsystem: "com.sleepyshark.carkey.watchkitapp",
    category: "ble"
)

// MARK: - State Enum

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

// MARK: - Watch Bluetooth Manager

class WatchBluetoothManager: NSObject, ObservableObject {
    static let shared = WatchBluetoothManager()

    @Published var state: BluetoothManagerState = .disconnected

    // CoreBluetooth
    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var isFound = false

    // Characteristics (mirrors BleTarget)
    private var authorizeRequestCharacteristic: CBCharacteristic?
    private var authorizeResponseCharacteristic: CBCharacteristic?
    private var controlRequestCharacteristic: CBCharacteristic?
    private var controlResponseCharacteristic: CBCharacteristic?

    // Key info
    private var keyInfo: E300BleKeyInfoModel?

    // Notification tracking
    private var authNotifyReady = false
    private var controlNotifyReady = false
    private var pendingAuthNotifications = 0

    // Scan timeout
    private var scanTimer: Timer?

    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)

        // 从后台恢复时检查连接状态
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkConnectionOnWake),
            name: Notification.Name("WKExtensionDidBecomeActive"),
            object: nil
        )
    }

    /// app 恢复前台时调用：验证 BLE 连接是否真的还在
    @objc private func checkConnectionOnWake() {
        guard let peripheral = targetPeripheral else { return }
        // peripheral.state == .connected 说明底层连接还在
        if peripheral.state != .connected {
            loggerBleWatchManager.warning("连接已丢失（后台恢复检测），重置状态")
            DispatchQueue.main.async { self.state = .disconnected }
            cleanup()
        } else {
            loggerBleWatchManager.debug("连接仍然有效")
        }
    }

    // MARK: - Public API

    func UpdateKey(key: E300BleKeyInfoModel) {
        self.keyInfo = key
        loggerBleWatchManager.info("key info updated")
    }
	
    func startScan() {
        guard centralManager.state == .poweredOn else {
            loggerBleWatchManager.error("Bluetooth not powered on, cannot scan")
            return
        }
		
		guard self.state == .disconnected else {
			loggerBleWatchManager.warning("Already connected! terminating new scan")
			return
		}
		
        loggerBleWatchManager.info("scan start")
        DispatchQueue.main.async {
            self.state = .scanning
        }
        isFound = false

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // 8-second timeout (same as iOS)
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.centralManager.stopScan()
			DispatchQueue.main.async {
				if self.state == .scanning {
					self.state = .disconnected
                }
                loggerBleWatchManager.info("scan timed out")
            }
        }
    }

    func CarLock() {
        let random = GenerateRandomHex8()
        GeneralControl(function: ControlFunctionList.doorLockAll, randomNumber: random)
    }

    func CarUnlock() {
        let random = GenerateRandomHex8()
        GeneralControl(function: ControlFunctionList.doorUnlockAll, randomNumber: random)
    }

    func CarPowerOff() {
        let random = GenerateRandomHex8()
        GeneralControl(function: ControlFunctionList.powerOff, randomNumber: random)
    }

    func GeneralControl(function: ControlFunctionList, randomNumber: String) {
        guard let keyInfo = self.keyInfo else {
            loggerBleWatchManager.error("failed to send control request, no key data")
            return
        }
        guard let requestChar = controlRequestCharacteristic,
              let peripheral = targetPeripheral else {
            loggerBleWatchManager.error("no control characteristic or peripheral")
            return
        }

        guard let payload = keyInfo.GenerateControlRequest(
            function: function,
            randomNum: randomNumber
        ).ToDataFromHexString() else {
            loggerBleWatchManager.error("failed to generate control payload")
            return
        }

        peripheral.writeValue(payload, for: requestChar, type: .withResponse)
        loggerBleWatchManager.info("control request sent: \(randomNumber)")
    }

    // MARK: - Disconnection

	func disconnect() {
        guard let peripheral = targetPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        loggerBleWatchManager.info("disconnecting from peripheral")
    }

    private func cleanup() {
        targetPeripheral?.delegate = nil
        targetPeripheral = nil
        authorizeRequestCharacteristic = nil
        authorizeResponseCharacteristic = nil
        controlRequestCharacteristic = nil
        controlResponseCharacteristic = nil
        authNotifyReady = false
        controlNotifyReady = false
        pendingAuthNotifications = 0
        scanTimer?.invalidate()
        scanTimer = nil
    }

    // MARK: - MAC Address Extraction

    private func getMacAddress(from manufacturerData: Data) -> String {
        guard manufacturerData.count >= 6 else { return "" }
        let macBytes = manufacturerData.suffix(6)
        return macBytes.ToHexEncodedString()
    }

    // MARK: - Authorization

    private func sendInitialAuthorizationRequest() {
        guard let keyInfo = self.keyInfo else {
            loggerBleWatchManager.error("failed to send initial auth request, no key data")
            return
        }
        guard let requestChar = authorizeRequestCharacteristic,
              let peripheral = targetPeripheral else { return }

        if let payload = keyInfo.GenerateRequest1().ToDataFromHexString() {
            peripheral.writeValue(payload, for: requestChar, type: .withResponse)
            loggerBleWatchManager.info("initial authorization request sent")
        }
    }

    private func sendSecondAuthorizationRequest() {
        guard let keyInfo = self.keyInfo else {
            loggerBleWatchManager.error("failed to send second auth request, no key data")
            return
        }
        guard let requestChar = authorizeRequestCharacteristic,
              let peripheral = targetPeripheral else { return }

        if let payload = keyInfo.GenerateRequest2().ToDataFromHexString() {
            peripheral.writeValue(payload, for: requestChar, type: .withResponse)
            loggerBleWatchManager.info("second authorization request sent")
        }
    }

    private func authOK() {
        DispatchQueue.main.async {
            self.state = .connected
        }
        self.keyInfo!.UpdateControlKey()
        loggerBleWatchManager.info("connected and authorized!")
    }

    // MARK: - Auth Response Handler

    private func handleAuthResponse(data: Data) {
        guard var keyInfo = self.keyInfo else {
            loggerBleWatchManager.error("no valid bt auth key")
            return
        }

        let responseData1 = UcuAuthorizationRequestFrame1(
            dataFrame: data,
            aesKey: keyInfo.authAesKey
        )

        if responseData1.serviceId != "A857" {
            loggerBleWatchManager.error(
                "notification with wrong service id \(responseData1.serviceId) in auth"
            )
        }

        switch responseData1.subfunction {
        case "0001":
            loggerBleWatchManager.info("entered auth stage 1")
            keyInfo.randomData1 = responseData1.random1
            if keyInfo.keyIdHex == responseData1.blekey.UnPadZero() {
                self.keyInfo = keyInfo
                loggerBleWatchManager.debug("auth stage 1 got random1: \(String(describing: keyInfo.randomData1))")
                sendSecondAuthorizationRequest()
            } else {
                loggerBleWatchManager.error("auth stage 1 got wrong key id: \(responseData1.blekey)")
            }

        case "0002":
            loggerBleWatchManager.info("entered auth stage 2")
            let responseData2 = UcuAuthorizationRequestFrame2(
                dataFrame: data,
                aesKey: keyInfo.authAesKey
            )
            if keyInfo.keyIdHex != responseData2.blekey.UnPadZero() {
                loggerBleWatchManager.error("auth stage 2 got wrong key id: \(responseData2.blekey)")
            }
            if keyInfo.randomData2 == responseData2.random2 {
                loggerBleWatchManager.debug("auth stage 2 correct random2")
                authOK()
            } else {
                loggerBleWatchManager.error("auth stage 2 wrong random2")
                disconnect()
            }

        default:
            loggerBleWatchManager.warning("unknown auth subfunction id: \(responseData1.subfunction)")
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension WatchBluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            loggerBleWatchManager.info("Bluetooth powered on")
        case .poweredOff:
            loggerBleWatchManager.warning("Bluetooth powered off")
            DispatchQueue.main.async { self.state = .disconnected }
            cleanup()
        case .unauthorized:
            loggerBleWatchManager.error("Bluetooth unauthorized")
        case .unsupported:
            loggerBleWatchManager.error("Bluetooth unsupported")
        case .resetting:
            loggerBleWatchManager.warning("Bluetooth resetting")
        case .unknown:
            loggerBleWatchManager.warning("Bluetooth unknown state")
        @unknown default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        guard !isFound,
              let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              let targetMac = self.keyInfo?.bleMacStr
        else { return }

        guard peripheral.name != nil else {
            loggerBleWatchManager.debug("device \(peripheral.identifier) has no name, ignoring")
            return
        }

        let discoveredMac = getMacAddress(from: manufacturerData)

        if discoveredMac.uppercased() == targetMac.uppercased() {
            loggerBleWatchManager.info("ble mac matched: \(discoveredMac)")
            isFound = true
            centralManager.stopScan()
            scanTimer?.invalidate()

            targetPeripheral = peripheral
            peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        loggerBleWatchManager.info("connected to \(peripheral.name ?? "unnamed")")
        DispatchQueue.main.async {
            self.state = .authorizing
        }

        // Discover services
        peripheral.discoverServices(SGMWBLEProfile.AllServicesUuid)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        loggerBleWatchManager.error("failed to connect: \(error?.localizedDescription ?? "unknown")")
        DispatchQueue.main.async { self.state = .disconnected }
        cleanup()
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        loggerBleWatchManager.warning("peripheral disconnected: \(error?.localizedDescription ?? "clean disconnect")")
        DispatchQueue.main.async { self.state = .disconnected }
        cleanup()
    }
}

// MARK: - CBPeripheralDelegate

extension WatchBluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            loggerBleWatchManager.error("service discovery failed: \(error)")
            disconnect()
            return
        }

        guard let services = peripheral.services else { return }

        for service in services {
            switch service.uuid {
            case SGMWBLEProfile.AuthorizeService.uuid:
                loggerBleWatchManager.debug("discovered authorize service")
                peripheral.discoverCharacteristics(nil, for: service)
            case SGMWBLEProfile.ControlService.uuid:
                loggerBleWatchManager.debug("discovered control service")
                peripheral.discoverCharacteristics(nil, for: service)
            default:
                loggerBleWatchManager.debug("discovered unknown service: \(service.uuid)")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            loggerBleWatchManager.error("characteristic discovery failed: \(error)")
            disconnect()
            return
        }

        guard let characteristics = service.characteristics else { return }
        assignCharacteristics(characteristics)
    }

    private func assignCharacteristics(_ characteristics: [CBCharacteristic]) {
        for characteristic in characteristics {
            switch characteristic.uuid {
            case SGMWBLEProfile.AuthorizeService.Characteristics.Request:
                authorizeRequestCharacteristic = characteristic
                loggerBleWatchManager.debug("got authorizeRequestCharacteristic")
            case SGMWBLEProfile.AuthorizeService.Characteristics.Response:
                authorizeResponseCharacteristic = characteristic
                loggerBleWatchManager.debug("got authorizeResponseCharacteristic")
            case SGMWBLEProfile.ControlService.Characteristics.Request:
                controlRequestCharacteristic = characteristic
                loggerBleWatchManager.debug("got controlRequestCharacteristic")
            case SGMWBLEProfile.ControlService.Characteristics.Response:
                controlResponseCharacteristic = characteristic
                loggerBleWatchManager.debug("got controlResponseCharacteristic")
            default:
                loggerBleWatchManager.debug("got unknown characteristic: \(characteristic.uuid)")
            }
        }

        // Check if all characteristics are discovered
        guard authorizeRequestCharacteristic != nil,
              authorizeResponseCharacteristic != nil,
              controlRequestCharacteristic != nil,
              controlResponseCharacteristic != nil
        else { return }

        loggerBleWatchManager.info("got all characteristics")
        setupNotifications()
    }

    private func setupNotifications() {
        guard let peripheral = targetPeripheral,
              let authResponseChar = authorizeResponseCharacteristic,
              let controlResponseChar = controlResponseCharacteristic
        else { return }

        loggerBleWatchManager.info("enabling notifications")

        pendingAuthNotifications = 2

        // Enable notification for authorize response
        peripheral.setNotifyValue(true, for: authResponseChar)

        // Enable notification for control response
        peripheral.setNotifyValue(true, for: controlResponseChar)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            loggerBleWatchManager.error("failed to set notify for \(characteristic.uuid): \(error)")
            disconnect()
            return
        }

        guard characteristic.isNotifying else { return }

        switch characteristic.uuid {
        case SGMWBLEProfile.AuthorizeService.Characteristics.Response:
            authNotifyReady = true
            loggerBleWatchManager.debug("authorize notifications ready")
        case SGMWBLEProfile.ControlService.Characteristics.Response:
            controlNotifyReady = true
            loggerBleWatchManager.debug("control notifications ready")
        default:
            break
        }

        pendingAuthNotifications -= 1

        // When both notifications are enabled, start authorization
        if authNotifyReady && controlNotifyReady && pendingAuthNotifications <= 0 {
            loggerBleWatchManager.info("all notifications ready, starting auth")
            sendInitialAuthorizationRequest()
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            loggerBleWatchManager.error("value update error: \(error)")
            return
        }

        guard let data = characteristic.value else {
            loggerBleWatchManager.warning("received notification with no value")
            return
        }

        loggerBleWatchManager.debug("received value for characteristic: \(characteristic.uuid)")

        switch characteristic.uuid {
        case SGMWBLEProfile.AuthorizeService.Characteristics.Response:
            handleAuthResponse(data: data)
        case SGMWBLEProfile.ControlService.Characteristics.Response:
            loggerBleWatchManager.debug("received control response: \(data.toHexString())")
        default:
            loggerBleWatchManager.debug("received value from unknown characteristic: \(characteristic.uuid)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            loggerBleWatchManager.error("write failed for \(characteristic.uuid): \(error)")
        } else {
            loggerBleWatchManager.debug("write succeeded for \(characteristic.uuid)")
        }
    }
}

// MARK: - Authorization Response Frames

struct UcuAuthorizationRequestFrame1 {
    let serviceId: String
    let subfunction: String
    let random1: String
    let blekey: String

    init(dataFrame: Data, aesKey: Data) {
        do {
            var dataHex: String = dataFrame.toHexString()
            if dataHex[0...1] != "00" {
                loggerBleWatchManager.error("received data not encrypted!")
            }
            dataHex = dataHex[2...]
            loggerBleWatchManager.debug("received data for 1st auth: \(dataHex)")

            let decrypted: [UInt8] = try AES(
                key: Array(aesKey),
                blockMode: ECB(),
                padding: .noPadding
            ).decrypt(Array(Data(hex: dataHex)))
            let decryptedString = decrypted.toHexString().uppercased()

            // CRC check
            if Data(decrypted).Crc16Checksum() != 0 {
                loggerBleWatchManager.warning("crc check failed on 1st auth response")
            }
            // Payload length check
            if Data(hex: String(decryptedString[32...33])).toHexString() != "01" {
                loggerBleWatchManager.warning("payload length check failed on 1st auth response")
            }

            let service = decryptedString[0...3]
            let subFunc = decryptedString[4...7]
            let random1 = decryptedString[16...23]
            let blekey = decryptedString[24...31]

            self.serviceId = String(service)
            self.subfunction = String(subFunc)
            self.random1 = String(random1)
            self.blekey = String(blekey)

            return
        } catch {
            loggerBleWatchManager.error("decrypt error on 1st auth: \(error)")
            self.serviceId = ""
            self.subfunction = ""
            self.random1 = ""
            self.blekey = ""
        }
    }
}

struct UcuAuthorizationRequestFrame2 {
    let serviceId: String
    let subfunction: String
    let random2: String
    let blekey: String

    init(dataFrame: Data, aesKey: Data) {
        do {
            var dataHex: String = dataFrame.toHexString()
            if dataHex[0...1] != "00" {
                loggerBleWatchManager.error("received data not encrypted!")
            }
            dataHex = dataHex[2...]
            loggerBleWatchManager.debug("received data for 2nd auth: \(dataHex)")

            let decrypted: [UInt8] = try AES(
                key: Array(aesKey),
                blockMode: ECB(),
                padding: .noPadding
            ).decrypt(Array(Data(hex: dataHex)))
            let decryptedString = decrypted.toHexString().uppercased()

            // CRC check
            if Data(decrypted).Crc16Checksum() != 0 {
                loggerBleWatchManager.warning("crc check failed on 2nd auth response")
            }
            // Payload length check
            if Data(hex: String(decryptedString[32...33])).toHexString() != "06" {
                loggerBleWatchManager.warning("payload length check failed on 2nd auth response")
            }

            let service = decryptedString[0...3]
            let subFunc = decryptedString[4...7]
            let random2 = decryptedString[16...23]
            let blekey = decryptedString[24...31]

            self.serviceId = String(service)
            self.subfunction = String(subFunc)
            self.random2 = String(random2)
            self.blekey = String(blekey)

            return
        } catch {
            loggerBleWatchManager.error("decrypt error on 2nd auth: \(error)")
            self.serviceId = ""
            self.subfunction = ""
            self.random2 = ""
            self.blekey = ""
        }
    }
}
