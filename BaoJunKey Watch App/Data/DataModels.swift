//
//  DataModels.swift
//  BaoJunKey Watch App
//
//  Ported data models from carkey/Data/Data.swift
//

import Foundation

// MARK: - User Data

struct UserData: Codable {
    var userName: String
    var accessToken: String
    var clientSecret: String
    var userID: String
}

// MARK: - Car Key Data

struct CarKeyAPIResponse: Decodable {
    let result: Bool
    let data: CarKeyData
    let systemDate: String
    let systemTimeMillis: Int
}

struct CarKeyData: Codable {
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

// MARK: - Vehicle Data

struct VehicleAPIResponse: Codable {
    let result: Bool
    let data: CarData
    let systemDate: String
    let systemTimeMillis: Int
}

struct CarData: Codable {
    let carStatus: CarStatus
    let carInfo: CarInfo
    let updateDate: String

    private enum CodingKeys: String, CodingKey {
        case carStatus
        case carInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        carStatus = try container.decode(CarStatus.self, forKey: .carStatus)
        carInfo = try container.decode(CarInfo.self, forKey: .carInfo)
        updateDate = Date().formatted(date: .numeric, time: .standard)
    }
}

struct CarStatus: Codable {
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

struct CarInfo: Codable {
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
    let purchaseDate: Int
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

// MARK: - App Data Container

struct AppData: Codable {
    var userData: UserData?
    var carKeyData: CarKeyData?
    var carData: CarData?
}
