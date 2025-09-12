//
//  Data.swift
//  carkey
//
//  Created by Shilapi Chen on 9/11/25.
//
import SwiftUI

class UserData: ObservableObject {
    @Published var userName: String = ""
    @Published var accessToken: String = ""
    @Published var clientSecret: String = ""
    @Published var userID: String = "" // 通常为手机号
    
    func login(userName: String, accessToken: String, clientSecret: String, userID: String) {
        self.userName = userName
        self.accessToken = accessToken
        self.clientSecret = clientSecret
        self.userID = userID
        
        // 同步修改sgmw的token
        DataManager.shared.sgmwUnifiedOAuth.updateToken(accesstoken: accessToken, clientsecret: clientSecret)
    }
}

class CarData: ObservableObject {
    @Published var vin: String = ""
    
    func setVin(vin: String) {
        self.vin = vin
    }
}

class DataManager {
    static let shared = DataManager()

    private init() {}

    let userData = UserData()
    let carData = CarData()
    let sgmwUnifiedOAuth = SGMWUnifiedOAuth()
}
