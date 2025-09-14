//
//  SGMW.swift
//  carkey
//
//  Created by Shilapi Chen on 9/9/25.
//
import Foundation
import SwiftUI
import CoreBluetooth

enum SGMWBLEProfile {
    enum UnknownSpectial {
        static let uuid = CBUUID(string: "F000FFD0-0451-4000-B000-000000000000")
    }
    
    enum AuthorizeService {
        static let uuid = CBUUID(string: "181A")
        
        enum Characteristics {
            // request by Write
            static let Request = CBUUID(string: "2A6E")
            // response by notify
            static let Response = CBUUID(string: "2A6F")
            
            static let AllCharacteristicsUuid = [
                Request,
                Response
            ]
        }
    }
    
    enum ControlService {
        static let uuid = CBUUID(string: "182A")
        
        enum Characteristics {
            // request by Write
            static let Request = CBUUID(string: "2A7E")
            // response by notify
            static let Response = CBUUID(string: "2A7F")
            
            static let AllCharacteristicsUuid = [
                Request,
                Response
            ]
        }
    }
    
    static let AllServicesUuid = [
        UnknownSpectial.uuid,
        AuthorizeService.uuid,
        ControlService.uuid
    ]
}



// MARK: - SGMW 统一认证模块

struct AuthParameters {
    let signature: String
    let nonce: String
    let timestamp: String
}


class SGMWUnifiedOAuth {
    
    // 静态配置
    private enum Config {
        static let clientId = "2019041810222516127"
        static let appCode = "sgmw_llb"
        static let system = "iOS"
        static let appVersion = "5.2.15"
        static let platformNo = "iOS"
        static var systemVersion: String { UIDevice.current.systemVersion }
    }
    
    // 动态状态
    private(set) var accessToken: String?
    private(set) var clientSecret: String?

    init() {}
    
    // login时调用
    func updateToken(accessToken: String, clientSecret: String) {
        self.accessToken = accessToken
        self.clientSecret = clientSecret
    }
    
    // logout时调用
    func clearToken() {
        self.accessToken = nil
        self.clientSecret = nil
    }

    /// 生成一个包含所有认证信息的 HTTP 请求头字典，用于网络请求。
    /// - Returns: 一个 [String: String] 格式的请求头字典，如果未登录则返回 nil
    public func generateAuthenticatedHeaders() -> [String: String]? {
        
        // 1. 调用内部方法生成动态参数 (签名, nonce, 时间戳)
        guard let authParams = generateAuthenticationParameters(appid: "1145141919810", phone: DataManager.shared.userData?.userID ?? "18000000001"),
              let currentAccessToken = self.accessToken,
              let currentClientSecret = self.clientSecret else {
            print("debug: failed to generate headers")
            return nil
        }
        
        let headers: [String: String] = [
            "sgmwclientid": Config.clientId,
            "sgmwaccesstoken": currentAccessToken,
            "sgmwtimestamp": authParams.timestamp,
            "sgmwplatformno": Config.platformNo,
            "sgmwappversion": Config.appVersion,
            "sgmwsystem": Config.system,
            "sgmwclientsecret": currentClientSecret,
            "sgmwappcode": Config.appCode,
            "sgmwsystemversion": Config.systemVersion,
            "sgmwsignature": authParams.signature,
            "sgmwnonce": authParams.nonce
        ]
        
        return headers
    }

    // 私有辅助方法
    
    private func generateAuthenticationParameters(appid: String, phone: String) -> AuthParameters? {
        guard let accessToken = self.accessToken, let clientSecret = self.clientSecret else { return nil }
        
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000))
        let nonce = UUID().uuidString
        let serialNumber = UIDevice.current.identifierForVendor?.uuidString ?? ""
        
        let signature = generateSign(
            appid: appid,
            timestamp: timestamp,
            nonce: nonce,
            accessNumber: accessToken,
            phone: phone,
            serialNumber: serialNumber,
            appKey: clientSecret
        )
        
        return AuthParameters(signature: signature, nonce: nonce, timestamp: timestamp)
    }

    private func generateSign(appid: String, timestamp: String, nonce: String, accessNumber: String, phone: String, serialNumber: String, appKey: String) -> String {
        let paramsForSign: [String: String] = ["appid": appid, "timestamp": timestamp, "nonce": nonce, "access_number": accessNumber, "phone": phone, "serial_number": serialNumber]
        let sortedSignString = sortSignValue(paramsForSign)
        let signSource = "\(sortedSignString)&appkey=\(appKey)"
        return signSource.generateMD5()
    }

    private func sortSignValue(_ params: [String: String]) -> String {
        let sortedKeys = params.keys.sorted()
        return sortedKeys.map { "\($0)=\(params[$0] ?? "")" }.joined(separator: "&")
    }
}
