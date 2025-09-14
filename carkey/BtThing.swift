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

// disconnected -> scan -> auth -> connected
enum BluetoothManagerState {
    case unknown
    case disconnected
    case authorizing
    case connected
    case scanning
}

extension Peripheral: @retroactive Identifiable {
    public var id: String {
        return self.name ?? self.identifier.uuidString
    }
}

struct E300BleKeyInfoModel {
    var bleMacStr: String?       // 从云端获取的车辆MAC地址
    var keyIdHex: String?        // 密钥ID
    var aes128Key: Data?         // 用于授权的AES密钥
    var controlAes128Key: Data?  // 用于控制的AES会话密钥
    var rollData: Data?          // 滚动码
    var randomData1: String?     // 车辆的随机数 (从车辆接收)
    var randomData2: String?     // App生成的随机数 (发送给车辆)
}

struct BleTarget {
    var peripheral: Peripheral
    var authorizeService: CBService?
    var authorizeRequestCharacteristic: CBCharacteristic?
    var authorizeResponseCharacteristic: CBCharacteristic?
    var controlService: CBService?
    var controlRequestCharacteristic: CBCharacteristic?
    var controlResponseCharacteristic: CBCharacteristic?
}

class BluetoothManager {
    static let shared = BluetoothManager()
    init(){}
    
    @Published var keyInfo: E300BleKeyInfoModel?
    
    @Published var avaliblePeripherals = [Peripheral]()
    @Published var target: BleTarget?
    
    @Published var state: BluetoothManagerState = BluetoothManagerState.disconnected
}

extension BluetoothManager: ObservableObject {
    func GetState() -> BluetoothManagerState {
        return self.state
    }
    
    func StartScan() {
        print("BtThing: scanning start")
        self.state = .scanning
        SwiftyBluetooth.scanForPeripherals(withServiceUUIDs: nil /*SGMWBLEProfile.Services.AllServices*/, timeoutAfter: 10) { scanResult in
            switch scanResult {
            case .scanStarted:
                self.state = BluetoothManagerState.scanning
            case .scanResult(let peripheral, _, _):
                self.onScanMatchCallback(peripheral: peripheral)
            case .scanStopped(let peripherals, let error):
                print("BtThing: scan ended")
                if self.state == .scanning {
                    self.state = .disconnected
                }
                self.avaliblePeripherals = peripherals
                if error != nil {
                    print("Encountered error during bt scanning: \(String(describing: error))")
                }
            }
        }
    }
	
	// 如果你把这里展开，你会看到一堆屎山，但是我tm不想分函数了
	private func onScanMatchCallback(peripheral: Peripheral) {
		// 没有设备名/没获取车数据return
		guard let name = peripheral.name,
			  DataManager.shared.carKeyData != nil else {return}
		
		// 通过设备名匹配，形如 BLE#0x609866F07BEB，不匹配return
		if name.contains(DataManager.shared.carKeyData?.bleMacString ?? "000000000000") != true {
			return
		}
		
		var target = BleTarget(peripheral: peripheral)
		
		target.peripheral.connect(withTimeout: 5){ result in
			switch result {
			case .success:
				print("BThing: ble connected")
				
				// 看一下设备的服务&特征，没有就连错了，断联
				target.peripheral.discoverServices(withUUIDs: SGMWBLEProfile.AllServicesUuid) { result in
					switch result {
					case .success(let services):
						print("BtThing: discovered services: \(services.map { $0.uuid.uuidString })")
						for service in services {
							
							// 是鉴权服务
							if service.uuid == SGMWBLEProfile.AuthorizeService.uuid {
								target.authorizeService = service
								target.peripheral.discoverCharacteristics(
									withUUIDs: SGMWBLEProfile.AuthorizeService.Characteristics.AllCharacteristicsUuid,
									ofServiceWithUUID: service.uuid
								) { result in
									switch result {
									case .success(let characteristics):
										for characteristic in characteristics {
											switch characteristic.uuid {
											case SGMWBLEProfile.AuthorizeService.Characteristics.Request:
												target.authorizeRequestCharacteristic = characteristic
											case SGMWBLEProfile.AuthorizeService.Characteristics.Response:
												target.authorizeResponseCharacteristic = characteristic
											default:
												print("BtThing: found unknown characteristic under authorize service with uuid: \(characteristic.uuid)")
											}
										}
									case .failure(let error):
										print("BtThing: unable to find target characteristics under authorize service, disconnecting: \(error)")
										self.disconnectPeripheral(peripheral: target.peripheral)
									}
								}
								
								// 是控制服务
							} else if service.uuid == SGMWBLEProfile.ControlService.uuid {
								target.controlService = service
								target.peripheral.discoverCharacteristics(
									withUUIDs: SGMWBLEProfile.ControlService.Characteristics.AllCharacteristicsUuid,
									ofServiceWithUUID: service.uuid
								) { result in
									switch result {
									case .success(let characteristics):
										for characteristic in characteristics {
											switch characteristic.uuid {
											case SGMWBLEProfile.ControlService.Characteristics.Request:
												target.controlRequestCharacteristic = characteristic
											case SGMWBLEProfile.ControlService.Characteristics.Response:
												target.controlResponseCharacteristic = characteristic
											default:
												print("BtThing: found unknown characteristic under control service with uuid: \(characteristic.uuid)")
											}
										}
									case .failure(let error):
										print("BtThing: unable to find target characteristics under control service, disconnecting: \(error)")
										self.disconnectPeripheral(peripheral: target.peripheral)
									}
								}
							}
						}
					case .failure(let error):
						print("BtThing: unable to find target services, disconnecting: \(error)")
						self.disconnectPeripheral(peripheral: target.peripheral)
					}
				}
				// 确定一下设备服务特征全了
				guard target.controlService != nil,
					  target.authorizeService != nil,
					  target.controlRequestCharacteristic != nil,
					  target.controlResponseCharacteristic != nil,
					  target.authorizeRequestCharacteristic != nil,
					  target.authorizeResponseCharacteristic != nil else {
					// 这里一定不能忘记断连
					self.disconnectPeripheral(peripheral: target.peripheral)
					return
				}
				
				// 回传target，注册auth的notification
				self.target = target
				// TODO: 注册notification
					  
				
			case .failure(let error):
				print("BtThing: failed to connect: \(error)")
			}
		}
	}
	
    private func authorize(peripheral: Peripheral) {
        
        
        
        
        // always disconnect if anything happend during authrization
        self.disconnectPeripheral(peripheral: peripheral)
    }
    
    private func disconnectPeripheral(peripheral: Peripheral) {
        peripheral.disconnect { result in
            switch result {
            case .success:
                self.target = nil
                self.state = .disconnected
                print("BtThing: disconnected")
            case .failure(let error):
                print("BtThing: failed to disconnect: \(error)")
            }
        }
    }
}

// MARK: - debugview

#if DEBUG

extension BluetoothManager {
    
}

import SwiftUI

struct btdebugview: View {
    @StateObject var bt = BluetoothManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("蓝牙")) {
                    Text("当前状态： \(bt.GetState())")
                    Button("开始扫描", action: {
                        bt.StartScan()
                    })
                }
            }
        }
    }
}


#Preview {
    btdebugview()
}

#endif
