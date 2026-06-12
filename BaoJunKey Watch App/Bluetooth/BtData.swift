//
//  BtData.swift
//  BaoJunKey Watch App
//
//  Ported from carkey/Bluetooth/BtData.swift
//  BLE command types, control functions, and key info model
//

import Foundation
import CryptoSwift
import OSLog

let loggerBleWatch = Logger(
    subsystem: "com.sleepyshark.carkey.watchkitapp",
    category: "ble"
)

// MARK: - BLE Command Types

enum BleCommandType {
    enum Service {
        static let PhoneAuthRequest   = "38C7"
        static let CarAuthResponse    = "A857"
        static let PhoneControlRequest = "39D6"
        static let CarControlResponse  = "A956"
    }

    enum Subfunc {
        static let AuthRound1 = "0001"
        static let AuthRound2 = "0002"
        static let Control    = "0001"
    }
}

// MARK: - Control Functions

enum ControlFunctionList: String {
    case doorLockAll   = "0102F2000000"
    case doorUnlockAll = "0101F2000000"
    case powerOff      = "0309000000"
}

// MARK: - BLE Key Info Model

struct E300BleKeyInfoModel {
    var bleMacStr: String
    var keyIdHex: String
    var authAesKey: Data
    var controlAesKey: Data?
    var rollData: Data?
    var randomData1: String?
    var randomData2: String
    var timestamp: String

    init(bleMac: String, keyId: String, masterKey: String, keyMasterRandom: String) {
        self.bleMacStr = bleMac.replacingOccurrences(of: ":", with: "").uppercased()
        self.keyIdHex = keyId.ToHexStringFromIntString()

        let masterKeyData = masterKey.ToDataFromHexString()!
        let keyMasterRandomData = keyMasterRandom.ToDataFromHexString()!
        self.authAesKey = masterKeyData.xor(withData: keyMasterRandomData)

        self.randomData2 = GenerateRandomHex8()
        self.timestamp = String(Int(Date().timeIntervalSince1970), radix: 16, uppercase: true)
    }
}

// MARK: - Key Info Methods

extension E300BleKeyInfoModel {
    mutating func UpdateControlKey() {
        guard let random1 = self.randomData1 else {
            loggerBleWatch.error("failed to retrieve random1 while attempting to update control key")
            return
        }
        let newControlAesKey = Data(hex: "\(random1)\(self.randomData2)\(random1)\(self.randomData2)")
        self.controlAesKey = newControlAesKey
        loggerBleWatch.debug("control key updated: \(newControlAesKey.toHexString())")
    }

    func GenerateRequest1() -> String {
        let service = BleCommandType.Service.PhoneAuthRequest
        let subfunc = BleCommandType.Subfunc.AuthRound1

        var payload = "\(service)\(subfunc)00000000\(self.timestamp)\(self.keyIdHex.PadZero(toLength: 8))06000000000000"
        guard let firstPayloadCrc = payload.ToDataFromHexString()?.Crc16Checksum() else {
            loggerBleWatch.error("failed to generate request 1: failed to convert payload to hex")
            return ""
        }
        payload = "\(payload)\(String(firstPayloadCrc, radix: 16, uppercase: true))".PadZeroOnTail(toLength: 64)
        loggerBleWatch.debug("payload generated for request 1: \(payload)")

        return payload
    }

    func GenerateRequest2() -> String {
        let service = BleCommandType.Service.PhoneAuthRequest
        let subfunc = BleCommandType.Subfunc.AuthRound2
        guard let randomData1 = self.randomData1 else {
            loggerBleWatch.error("failed to fetch random1")
            return ""
        }

        var payload = "\(service)\(subfunc)\(self.randomData2)\(randomData1)\(self.keyIdHex.PadZero(toLength: 8))06000000000000"
        guard let firstPayloadCrc = payload.ToDataFromHexString()?.Crc16Checksum() else {
            loggerBleWatch.error("failed to generate request 2: failed to convert payload to hex")
            return ""
        }
        payload = "\(payload)\(String(firstPayloadCrc, radix: 16, uppercase: true))".PadZeroOnTail(toLength: 64)
        loggerBleWatch.debug("payload generated for request 2: \(payload)")

        do {
            let encryptedPayload = try AES(key: Array(self.authAesKey), blockMode: ECB(), padding: .noPadding).encrypt(Array(Data(hex: payload)))
            loggerBleWatch.debug("payload encrypted for request 2")
            return Data(encryptedPayload).toHexString()
        } catch {
            loggerBleWatch.error("payload encrypt error for request2: \(error)")
            return payload
        }
    }

    func GenerateControlRequest(function: ControlFunctionList, randomNum: String) -> String {
        let service = BleCommandType.Service.PhoneControlRequest
        let subfunc = BleCommandType.Subfunc.Control
        guard let controlAesKey = self.controlAesKey else {
            loggerBleWatch.error("failed to generate control request: no aes key")
            return ""
        }

        var payload = "\(service)\(subfunc)00000000\(randomNum)\(self.keyIdHex.PadZero(toLength: 8))06\(function.rawValue)"
        guard let firstPayloadCrc = payload.ToDataFromHexString()?.Crc16Checksum() else {
            loggerBleWatch.error("failed to generate control request: failed to convert payload to hex")
            return ""
        }
        payload = "\(payload)\(String(firstPayloadCrc, radix: 16, uppercase: true))".PadZeroOnTail(toLength: 64)
        loggerBleWatch.debug("payload generated for control request: \(payload)")

        do {
            let encryptedPayload = try AES(key: Array(controlAesKey), blockMode: ECB(), padding: .noPadding).encrypt(Array(Data(hex: payload)))
            loggerBleWatch.debug("payload encrypted for control request")
            return Data(encryptedPayload).toHexString()
        } catch {
            loggerBleWatch.error("payload encrypt error for control request: \(error)")
            return payload
        }
    }
}
