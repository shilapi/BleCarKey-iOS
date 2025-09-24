//
//  Debug.swift
//  carkey
//
//  Created by Shilapi Chen on 9/13/25.
//

import Foundation

// MARK: - 模拟数据生成器 (仅在 Debug 模式下有效)

#if DEBUG
// 为你的数据模型扩展，提供一个静态的 mock 实例
extension UserData {
    static var mock: UserData {
        UserData(userName: "Mock User",
                 accessToken: "mock_access_token_12345",
                 clientSecret: "mock_client_secret_67890",
                 userID: "18812345678")
    }
}

extension CarKeyData {
    static var mock: CarKeyData {
        // 使用之前解析函数中的 JSON 字符串来创建模拟数据
        let jsonString = """
        {"result":true,"data":{"collectTime":"2025-09-12 00:38:52.615","keyId":"382296","keyType":"owner","keyMasterRandom":"1843637FA0D12FDF39578B6D15935F98","masterKey":"8ED0DB094F0343BF61D86763F1216000","bleMac":"60:98:66:F0:7B:EB","endTime":"2038-01-01 00:00:00","userId":"18501754337","vin":"LK6ADAE46PB641378"},"systemDate":"2025-09-12 00:38:52","systemTimeMillis":1757608732650}
        """
        if let data = jsonString.data(using: .utf8),
           let keyData = try? JSONDecoder().decode(CarKeyAPIResponse.self, from: data),
            keyData.result {
             return keyData.data
         }
        // 如果解析失败，返回一个默认值
        fatalError("无法创建模拟 CarKeyData")
    }
}

extension CarData {
    static var mock: CarData {
        // 使用之前解析函数中的 JSON 字符串来创建模拟数据
        let jsonString = """
{"result":true,"data":{"carStatus":{"status":"5","statusToast":"","statusName":"补电中","leftTurnLight":"0","positionLight":"0","rightTurnLight":"0","dipHeadLight":"0","lowBeamLight":"0","leftFuel":"0","keyStatus":"0","autoGearStatus":"3","window4Status":"0","window3Status":"0","window2Status":"0","window1Status":"0","windowStatus":"0","door4OpenStatus":"0","door3OpenStatus":"0","door3LockStatus":"0","door4LockStatus":"0","lowBatVol":"12.14","batterySoc":"91","batAvgTemp":"27","door2OpenStatus":"0","latitude":"31.362814","batMinTemp":"27","doorLockStatus":"0","doorOpenStatus":"0","sentinelModeStatus":"0","leftMileage":"417","vecChrgingSts":"0","vecChrgStsIndOn":"0","obcOtpCur":"0","door2LockStatus":"0","current":"0","batSOH":"96","invActTemp":"28","leftBatteryPower":"44.9","door1OpenStatus":"0","tailDoorOpenStatus":"0","longitude":"121.366828","vehSpdAvgDrvn":"0","strWhAng":"10.125","brakPedalPos":"0","mileage":"33510","batMaxTemp":"27","accActPos":"0","batHealth":"96","collectTime":"2025-09-11 19:19:11","charging":"0","door1LockStatus":"0","voltage":"2","cdjTemp":"","acStatus":"0","tailDoorLockStatus":"0","wireConnect":"0","rechargeStatus":"0","limitFeedback":"0","batteryStatus":"1","accCntTemp":23.0,"yesterMileage":"0","window1OpenDegree":"0","window2OpenDegree":"0","window3OpenDegree":"0","window4OpenDegree":"0","interiorTemperature":"21","oilLeftMileage":"0","batteryIndicate":"","hybridMileage":"","chargePower":"","seat1HotStatus":"7","seat2HotStatus":"7","seat3HotStatus":"7","seat4HotStatus":"7","seat1WindStatus":"7","seat2WindStatus":"7","seat3WindStatus":"7","seat4WindStatus":"7","intelligentCarSwitch":2},"carInfo":{"vin":"LK6ADAE46PB641378","relation":1,"carName":"☁️","carPlate":"","vsn":"AH0M","providerCode":"desai","carTypeName":"宝骏云朵","model":"460 Max 灵犀版","level":"LV2大疆版","engineType":1,"image":"https://cdn-df.00bang.cn/images/T1oT_TB5_T1RCvBVdK.png","controlView":3,"bleType":2,"hasMoreCar":0,"folderUrl":"","shakeLock":1,"physicsEngine":1,"supportMqtt":1,"supportCarConditionPoll":1,"conditionPollTime":3,"isAuthIdentity":1,"bluetoothKeyConnectMark":"1","imageNameRule":[],"telematicsPlatform":0,"showWidgets":true,"telematicsCarStatus":1,"carPosition":1,"carYear":"2023","colorCode":"4K","carInfoId":14030320,"bindCarUserMobile":"18501754337","onlyLocalInfo":false,"colorName":"松石绿","purchaseDate":1698595200000,"purchaseUserName":"王萍","purchaseShopNum":"N319001","supportBatteryIndicate":0,"supportChargeRemain":0,"supportChargePower":0,"supportAvgFuel":0,"supportHybridMileage":0,"supportAutoAir":1,"supportAvgElectronFuel":0,"powerType":"13261005","carOwnerDay":684,"supportNewCarUi":0,"seriesCode":"Car-C-EQ100"}},"systemDate":"2025-09-12 00:38:45","systemTimeMillis":1757608725895}
"""
        // 为了简化，上面的JSON只保留了几个关键字段
        if let data = jsonString.data(using: .utf8),
           let response = try? JSONDecoder().decode(VehicleAPIResponse.self, from: data),
           response.result {
            return response.data
        }
        fatalError("无法创建模拟 CarData")
    }
}

// MARK: - 在 DataManager 中添加注入方法

extension DataManager {
    /// 这个方法只在 Debug 配置下存在
    func injectMockData() {
        print(" MOCK: 正在注入模拟数据...")
        DispatchQueue.main.async {
			self.appData.userData = UserData.mock
			self.appData.carKeyData = CarKeyData.mock
			self.appData.carData = CarData.mock
        }
    }
    
    /// 清除所有数据，方便测试
    func clearAllData() {
        DispatchQueue.main.async {
			self.appData.userData = nil
			self.appData.carKeyData = nil
			self.appData.carData = nil
        }
    }
}

// MARK: - view

import SwiftUI

/// 一个只在 SwiftUI 预览中显示的视图，包含注入和清除模拟数据的按钮
struct PreviewMockDataInjector: View {
    
    // 检查是否正在为 SwiftUI 预览运行
    private var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    var body: some View {
        // 只在 SwiftUI 预览画布中显示这个视图
        if isRunningForPreviews {
            VStack {
                Text("仅预览可见")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(5)

                HStack {
                    Button(action: {
                        DataManager.shared.injectMockData()
                    }) {
                        Text("注入模拟数据")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        DataManager.shared.clearAllData()
                    }) {
                        Text("清除数据")
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
    }
}

#endif
