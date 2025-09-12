//
//  NetThing.swift
//  carkey
//
//  Created by Shilapi Chen on 9/8/25.
//
import Foundation
import UIKit
import CoreLocation

// api请求协议
protocol EndpointType {
    var path: String { get }
    var method: String { get }
    var body: [String: Any]? { get }
}

enum BaojunEndpoint {
    // 查询默认车辆状态
    case queryDefaultCarStatus
    
    // 一个带有请求体的 POST 接口，例如发送车辆控制命令
    case queryBleKey(vin: String, userId: String)
    
}

extension BaojunEndpoint: EndpointType {
    var path: String {
        switch self {
        case .queryDefaultCarStatus:
            return "/junApi/sgmw/userCarRelation/queryDefaultCarStatus"
        case .queryBleKey(vin: _, userId: _):
            return "/junApi/sgmw/car/control/ble/key/query"
        }
    }
    
    // 接口的 HTTP 方法
    var method: String {
        switch self {
        case .queryDefaultCarStatus:
            return "POST"
        case .queryBleKey:
            return "POST"
        }
    }
    
    // 接口的请求体
    var body: [String: Any]? {
        switch self {
        case .queryDefaultCarStatus:
            return nil
        case .queryBleKey(let vin, let userId):
            return ["vin": vin, "userId": userId]
        }
    }
}

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}
    private let session = URLSession.shared
}

// General part
extension NetworkManager {
    func request(_ request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        let task = session.dataTask(with: request) { data, response, error in
            // 错误处理
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // 判断响应是否是 HTTP 响应
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                    // 判断状态码是否在 200-299 之间，这之间表示请求成功，否则抛出错误
                let statusError = NSError(domain: "com.networking.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response"])
                completion(.failure(statusError))
                return
            }
            
            // 判断返回的数据是否存在，如果存在则调用 completion 回调
            if let data = data {
                completion(.success(data))
            }
        }
          
        // 开始执行网络请求任务
        task.resume()
    }
}

// Baojun Part
extension NetworkManager {
    // 参数 url: URL，请求的 URL 地址
    // 参数 completion: @escaping (Result<Data, Error>) -> Void，请求完成后的回调
    func requestBaojun(_ endpoint: EndpointType, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let baseURL = URL(string: "https://openapi.baojun.net"),
                      let url = URL(string: baseURL.absoluteString + endpoint.path) else {
                    let error = NSError(domain: "NetworkManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                    completion(.failure(error))
                    return
                }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("accept", forHTTPHeaderField: "application/json")
        
        // 添加OAuth
        DataManager.shared.sgmwUnifiedOAuth.generateAuth()
        request.setValue(DataManager.shared.sgmwUnifiedOAuth.clientid, forHTTPHeaderField: "sgmwclientid")
        request.setValue(DataManager.shared.sgmwUnifiedOAuth.accesstoken, forHTTPHeaderField: "sgmwaccesstoken")
        request.setValue(DataManager.shared.sgmwUnifiedOAuth.timestamp, forHTTPHeaderField: "sgmwtimestamp")
        //request.setValue(DataManager.shared.sgmwUnifiedOAuth.platformno, forHTTPHeaderField: "sgmwplatformno")
        request.setValue(DataManager.shared.sgmwUnifiedOAuth.appversion, forHTTPHeaderField: "sgmwappversion")
        request.setValue(DataManager.shared.sgmwUnifiedOAuth.system, forHTTPHeaderField: "sgmwsystem")
        request.setValue(DataManager.shared.sgmwUnifiedOAuth.clientsecret, forHTTPHeaderField: "sgmwclientsecret")
        request.setValue(DataManager.shared.sgmwUnifiedOAuth.appcode, forHTTPHeaderField: "sgmwappcode")
        request.setValue(DataManager.shared.sgmwUnifiedOAuth.systemversion, forHTTPHeaderField: "sgmwsystemversion")
        request.setValue(DataManager.shared.sgmwUnifiedOAuth.signature, forHTTPHeaderField: "sgmwsignature")
        request.setValue(DataManager.shared.sgmwUnifiedOAuth.nounce, forHTTPHeaderField: "sgmwnonce")
        
        // Advanced device info
        let device = UIDevice.current
        let appInfo = Bundle.main.infoDictionary
        let deviceModel = device.model
        let platformVersion = device.systemVersion
        let deviceBrand = "Apple" // This is a constant for iOS devices
        let appVersion = appInfo?["CFBundleShortVersionString"] as? String ?? "unknown"
        let appBuild = appInfo?["CFBundleVersion"] as? String ?? "unknown"
        request.setValue("73", forHTTPHeaderField: "accessChannel")
        request.setValue("%E4%B8%8A%E6%B5%B7%E5%B8%82", forHTTPHeaderField: "cityName")
        request.setValue(getDeviceModelIdentifier(), forHTTPHeaderField: "deviceType")
        request.setValue("iOS", forHTTPHeaderField: "platformNo")
        request.setValue("App Store", forHTTPHeaderField: "channel")
        request.setValue(platformVersion, forHTTPHeaderField: "platformVersion")
        request.setValue("31.262702401106353", forHTTPHeaderField: "latitude")
        request.setValue(appVersion, forHTTPHeaderField: "version")
        request.setValue(appBuild, forHTTPHeaderField: "build")
        request.setValue(deviceModel, forHTTPHeaderField: "deviceModel")
        request.setValue("121.65264383085028", forHTTPHeaderField: "longitude")
        request.setValue(deviceBrand, forHTTPHeaderField: "deviceBrand")
        
        // 如果有请求体，则设置
        if let bodyData = endpoint.body,
           let jsonData = try? JSONSerialization.data(withJSONObject: bodyData, options: []) {
            request.httpBody = jsonData
        }
        
        self.request(request, completion: completion)
    }
}
