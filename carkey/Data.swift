//
//  Data.swift
//  carkey
//
//  Created by Shilapi Chen on 9/11/25.
//
import Foundation
import SwiftUI
import Combine

struct UserData {
    var userName: String
    var accessToken: String
    var clientSecret: String
    var userID: String
}

struct CarKeyAPIResponse: Decodable {
    let result: Bool
    let data: CarKeyData
    let systemDate: String
    let systemTimeMillis: Int
}

struct CarKeyData: Decodable {
    var collectTime: String
    var keyId: String
    var keyType: String
    var keyMasterRandom: String
    var masterKey: String
    var bleMac: String
    var endTime: String
    var userId: String
    var vin: String

    var collectDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.date(from: collectTime)
    }

    var bleMacString: String {
        return bleMac
            .replacingOccurrences(of: ":", with: "")
            .uppercased()
    }
}

struct VehicleAPIResponse: Decodable {
    let result: Bool
    let data: CarData
    let systemDate: String
    let systemTimeMillis: Int
}

struct CarData: Decodable {
    let carStatus: CarStatus
    let carInfo: CarInfo
}

struct CarStatus: Decodable {
    let status, statusToast, statusName, leftTurnLight: String
    let positionLight, rightTurnLight, dipHeadLight, lowBeamLight: String
    let leftFuel, keyStatus, autoGearStatus, window4Status: String
    let window3Status, window2Status, window1Status, windowStatus: String
    let door4OpenStatus, door3OpenStatus, door3LockStatus, door4LockStatus: String
    let lowBatVol, batterySoc, batAvgTemp, door2OpenStatus: String
    let latitude, batMinTemp, doorLockStatus, doorOpenStatus: String
    let sentinelModeStatus, leftMileage, vecChrgingSts, vecChrgStsIndOn: String
    let obcOtpCur, door2LockStatus, current, batSOH: String
    let invActTemp, leftBatteryPower, door1OpenStatus, tailDoorOpenStatus: String
    let longitude, vehSpdAvgDrvn, strWhAng, brakPedalPos: String
    let mileage, batMaxTemp, accActPos, batHealth: String
    let collectTime, charging, door1LockStatus, voltage: String
    let cdjTemp, acStatus, tailDoorLockStatus, wireConnect: String
    let rechargeStatus, limitFeedback, batteryStatus: String
    let accCntTemp: Double
    let yesterMileage, window1OpenDegree, window2OpenDegree, window3OpenDegree: String
    let window4OpenDegree, interiorTemperature, oilLeftMileage, batteryIndicate: String
    let hybridMileage, chargePower: String
    let seat1HotStatus, seat2HotStatus, seat3HotStatus, seat4HotStatus: String
    let seat1WindStatus, seat2WindStatus, seat3WindStatus, seat4WindStatus: String
    let intelligentCarSwitch: Int

    var batterySOCPercentage: Int? { Int(batterySoc) }
    var remainingMileage: Int? { Int(leftMileage) }
    var interiorTemp: Double? { Double(interiorTemperature) }
}

struct CarInfo: Decodable {
    let vin: String
    let relation: Int
    let carName, carPlate, vsn, providerCode: String
    let carTypeName, model, level: String
    let engineType: Int
    let image: String
    let controlView, bleType, hasMoreCar: Int
    let folderUrl: String
    let shakeLock, physicsEngine, supportMqtt, supportCarConditionPoll: Int
    let conditionPollTime, isAuthIdentity: Int
    let bluetoothKeyConnectMark: String
    let imageNameRule: [String]
    let telematicsPlatform: Int
    let showWidgets: Bool
    let telematicsCarStatus, carPosition: Int
    let carYear, colorCode: String
    let carInfoId: Int
    let bindCarUserMobile: String
    let onlyLocalInfo: Bool
    let colorName: String
    let purchaseDate: Int // 毫秒时间戳
    let purchaseUserName, purchaseShopNum: String
    let supportBatteryIndicate, supportChargeRemain, supportChargePower, supportAvgFuel: Int
    let supportHybridMileage, supportAutoAir, supportAvgElectronFuel: Int
    let powerType: String
    let carOwnerDay: Int
    let supportNewCarUi: Int
    let seriesCode: String
    
    var purchaseDateAsDate: Date {
        let timeInterval = TimeInterval(purchaseDate) / 1000.0
        return Date(timeIntervalSince1970: timeInterval)
    }
}


class DataManager: ObservableObject {
    
    static let shared = DataManager()
    
    @Published var userData: UserData?
    @Published var carKeyData: CarKeyData?
    @Published var carData: CarData?
    
    let sgmwUnifiedOAuth = SGMWUnifiedOAuth()
    
    private init() {}
}

extension DataManager {

    func login(userName: String, accessToken: String, clientSecret: String, userID: String) {
        let newUser = UserData(userName: userName, accessToken: accessToken, clientSecret: clientSecret, userID: userID)
        DispatchQueue.main.async {
            self.userData = newUser
            print("debug: logged in as \(newUser.userID)")
        }
        sgmwUnifiedOAuth.updateToken(accessToken: newUser.accessToken, clientSecret: newUser.clientSecret)
    }

    func logout() {
        DispatchQueue.main.async {
            self.userData = nil
            self.carKeyData = nil
            self.carData = nil
            print("debug: logged out")
        }
    }

    /// 从JSON加载并更新蓝牙密钥数据
    func loadKeyData(from jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8) else { return }
        do {
            let apiResponse = try JSONDecoder().decode(CarKeyAPIResponse.self, from: jsonData)
            guard apiResponse.result else {
                print("loadKeyData: failed to load BLE key: server returned false")
                return
            }
            DispatchQueue.main.async {
                self.carKeyData = apiResponse.data
                print("loadKeyData: BLE key data loaded for VIN: \(apiResponse.data.vin)")
            }
        } catch {
            print("loadKeyData: failed to load BLE key: \(error)")
        }
    }

    /// 从JSON加载并更新车辆综合数据
    func loadCarData(from jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("loadCarData: failed to parse car data json")
            return
        }
        
        do {
            let apiResponse = try JSONDecoder().decode(VehicleAPIResponse.self, from: jsonData)
            guard apiResponse.result else {
                print("loadCarData: API returned false")
                return
            }
            DispatchQueue.main.async {
                self.carData = apiResponse.data
                print("loadCarData: successed for \(apiResponse.data.carInfo.carTypeName)")
            }
        } catch {
            print("loadCarData: failed to parse car data json: \(error)")
        }
    }
}


// MARK: - 3. SwiftUI 示例视图
// 这个视图展示了如何订阅和使用 DataManager 中的数据。
struct CompleteDemoView: View {
    
    // 使用 @StateObject 来订阅单例的变化
    @StateObject private var dataManager = DataManager.shared
    
    // 模拟从API获取的JSON字符串
    let sampleKeyJson = """
    {"collectTime":"2025-09-12 00:38:48.032","keyId":"382296","keyType":"owner","keyMasterRandom":"1843637FA0D12FDF39578B6D15935F98","masterKey":"8ED0DB094F0343BF61D86763F1216000","bleMac":"60:98:66:F0:7B:EB","endTime":"2038-01-01 00:00:00","userId":"18501754337","vin":"LK6ADAE46PB641378"}
    """
    
    let sampleCarDataJson = """
    {"result":true,"data":{"carStatus":{"status":"5","statusToast":"","statusName":"补电中","leftTurnLight":"0","positionLight":"0","rightTurnLight":"0","dipHeadLight":"0","lowBeamLight":"0","leftFuel":"0","keyStatus":"0","autoGearStatus":"3","window4Status":"0","window3Status":"0","window2Status":"0","window1Status":"0","windowStatus":"0","door4OpenStatus":"0","door3OpenStatus":"0","door3LockStatus":"0","door4LockStatus":"0","lowBatVol":"12.14","batterySoc":"91","batAvgTemp":"27","door2OpenStatus":"0","latitude":"31.362814","batMinTemp":"27","doorLockStatus":"0","doorOpenStatus":"0","sentinelModeStatus":"0","leftMileage":"417","vecChrgingSts":"0","vecChrgStsIndOn":"0","obcOtpCur":"0","door2LockStatus":"0","current":"0","batSOH":"96","invActTemp":"28","leftBatteryPower":"44.9","door1OpenStatus":"0","tailDoorOpenStatus":"0","longitude":"121.366828","vehSpdAvgDrvn":"0","strWhAng":"10.125","brakPedalPos":"0","mileage":"33510","batMaxTemp":"27","accActPos":"0","batHealth":"96","collectTime":"2025-09-11 19:19:11","charging":"0","door1LockStatus":"0","voltage":"2","cdjTemp":"","acStatus":"0","tailDoorLockStatus":"0","wireConnect":"0","rechargeStatus":"0","limitFeedback":"0","batteryStatus":"1","accCntTemp":23.0,"yesterMileage":"0","window1OpenDegree":"0","window2OpenDegree":"0","window3OpenDegree":"0","window4OpenDegree":"0","interiorTemperature":"21","oilLeftMileage":"0","batteryIndicate":"","hybridMileage":"","chargePower":"","seat1HotStatus":"7","seat2HotStatus":"7","seat3HotStatus":"7","seat4HotStatus":"7","seat1WindStatus":"7","seat2WindStatus":"7","seat3WindStatus":"7","seat4WindStatus":"7","intelligentCarSwitch":2},"carInfo":{"vin":"LK6ADAE46PB641378","relation":1,"carName":"☁️","carPlate":"","vsn":"AH0M","providerCode":"desai","carTypeName":"宝骏云朵","model":"460 Max 灵犀版","level":"LV2大疆版","engineType":1,"image":"https://cdn-df.00bang.cn/images/T1oT_TB5_T1RCvBVdK.png","controlView":3,"bleType":2,"hasMoreCar":0,"folderUrl":"","shakeLock":1,"physicsEngine":1,"supportMqtt":1,"supportCarConditionPoll":1,"conditionPollTime":3,"isAuthIdentity":1,"bluetoothKeyConnectMark":"1","imageNameRule":[],"telematicsPlatform":0,"showWidgets":true,"telematicsCarStatus":1,"carPosition":1,"carYear":"2023","colorCode":"4K","carInfoId":14030320,"bindCarUserMobile":"18501754337","onlyLocalInfo":"false","colorName":"松石绿","purchaseDate":1698595200000,"purchaseUserName":"王萍","purchaseShopNum":"N319001","supportBatteryIndicate":0,"supportChargeRemain":0,"supportChargePower":0,"supportAvgFuel":0,"supportHybridMileage":0,"supportAutoAir":1,"supportAvgElectronFuel":0,"powerType":"13261005","carOwnerDay":683,"supportNewCarUi":0,"seriesCode":"Car-C-EQ100"}},"systemDate":"2025-09-11 21:23:58","systemTimeMillis":1757597038961}
    """
    
    var body: some View {
        NavigationView {
            List {
                // 用户信息区
                Section(header: Text("用户信息")) {
                    if let user = dataManager.userData {
                        Text("用户名: \(user.userName)")
                        Text("用户ID: \(user.userID)")
                        Button("登出", role: .destructive) { dataManager.logout() }
                    } else {
                        Button("登录") {
                            dataManager.login(userName: "Lapi", accessToken: "token123", clientSecret: "secret456", userID: "18501754337")
                        }
                    }
                }
                
                // 车辆信息区
                Section(header: Text("车辆信息")) {
                    if let carInfo = dataManager.carData?.carInfo {
                        Text("车型: \(carInfo.carTypeName)")
                        Text("车名: \(carInfo.carName)")
                        Text("颜色: \(carInfo.colorName)")
                    } else {
                        Text("无车辆信息")
                    }
                }
                
                // 车辆状态区
                Section(header: Text("车辆状态")) {
                    if let carStatus = dataManager.carData?.carStatus {
                        Text("状态: \(carStatus.statusName)")
                        Text("续航: \(carStatus.remainingMileage ?? 0) km")
                        Text("电量: \(carStatus.batterySOCPercentage ?? 0)%")
                    } else {
                        Text("无车辆状态")
                    }
                }
                
                // 蓝牙密钥区
                Section(header: Text("蓝牙密钥")) {
                    if let keyData = dataManager.carKeyData {
                        Text("密钥类型: \(keyData.keyType)")
                        Text("MAC地址: \(keyData.bleMacString)")
                    } else {
                        Text("无蓝牙密钥信息")
                    }
                }
                
                // 操作区
                Section(header: Text("操作")) {
                    Button("加载/刷新车辆数据") {
                        dataManager.loadCarData(from: sampleCarDataJson)
                    }
                    Button("加载/刷新蓝牙密钥") {
                        dataManager.loadKeyData(from: sampleKeyJson)
                    }
                }
            }
            .navigationTitle("车辆控制中心")
        }
    }
}

#Preview {
    CompleteDemoView()
}
