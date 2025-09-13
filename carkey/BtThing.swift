//
//  BtThing.swift
//  carkey
//
//  Created by Shilapi Chen on 9/12/25.
//

import Foundation
import SwiftyBluetooth
import CoreBluetooth
import Combine

enum BluetoothManagerState {
    case unknown
    case disconnected
    case connecting
    case connected
}

class BluetoothManager {
    static let shared = BluetoothManager()
    init(){}
    
    var isScanning = false
    var avaliblePeripherals = [Peripheral]()
    var targetPeripheral: Peripheral?
    var state = BluetoothManagerState.disconnected
}

extension BluetoothManager {
    func GetState() -> BluetoothManagerState {
        return self.state
    }
    
    func StartScan() {
        SwiftyBluetooth.scanForPeripherals(withServiceUUIDs: SGMWBLEProfile.Services.AllServices, timeoutAfter: 10) { scanResult in
            switch scanResult {
                case .scanStarted:
                    self.state = BluetoothManagerState.connecting
            case .scanResult(let peripheral, _, _):
                    self.targetPeripheral = peripheral
                case .scanStopped(let peripherals, let error):
                    self.avaliblePeripherals = peripherals
                    if error != nil {
                        print("Encountered error during bt scanning: \(String(describing: error))")
                    }
            }
        }
    }
}
