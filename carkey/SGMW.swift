//
//  SGMW.swift
//  carkey
//
//  Created by Shilapi Chen on 9/9/25.
//
import Foundation
import SwiftUI

class SGMWUnifiedOAuth: ObservableObject {
    // 在llb app内恒定的参数
    let clientid: String = "2019041810222516127"
    let appcode: String = "sgmw_llb"
    let system: String = "iOS"
    let appversion: String = "5.2.15"
    let platformno: String = "iOS"
    let systemversion: String = "18.6"
    
    // 用户相关
    @Published var accesstoken: String = ""
    @Published var clientsecret: String = ""
    
    // auth
    @Published var signature: String = ""
    @Published var nounce: String = ""
    @Published var timestamp: String = ""
    
    init() {}
    
    func generateAuth() {
        let now = Int(CLongLong(round(Date().timeIntervalSince1970*1000)))
        self.timestamp = String(now)
        
        self.nounce = UUID().uuidString
        
        self.signature = generateSign(
            appid: "1145141919810",
            timestamp: String(Date().timeIntervalSince1970),
            nonce: self.nounce,
            accessNumber: self.accesstoken,
            phone: "18000000001",
            serialNumber: UIDevice.current.identifierForVendor?.uuidString,
            appkey: self.clientsecret)
    }
    
    func updateToken(accesstoken: String, clientsecret: String) {
        self.accesstoken = accesstoken
        self.clientsecret = clientsecret
    }
}

func generateSign(appid: String?, timestamp: String?, nonce: String?, accessNumber: String?, phone: String?, serialNumber: String?, appkey: String?) -> String {
    let paramsForSign: [String: String] = [
        "appid": appid ?? "",
        "timestamp": timestamp ?? "",
        "nonce": nonce ?? "",
        "access_number": accessNumber ?? "",
        "phone": phone ?? "",
        "serial_number": serialNumber ?? ""
    ]
    
    // 1) 排序拼接
    let sortedSignString = sortSignValue(paramsForSign)
    
    // 2) 拼接 appkey 并 md5
    let signSource = "\(sortedSignString)&appkey=\(appkey ?? "")"
    let sign = signSource.md5
    return sign
}

func sortSignValue(_ params: [String: String]) -> String {
    let sortedKeys = params.keys.sorted()
    let pairs = sortedKeys.map { "\($0)=\(params[$0] ?? "")" }
    return pairs.joined(separator: "&")
}

